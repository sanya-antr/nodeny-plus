#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use XML::Simple;
use Digest::SHA1 qw( sha1 sha1_hex );
use MIME::Base64;

$cfg::main_config = '/usr/local/nodeny/sat.cfg';

# -------------------------------------------------------------------------

$cfg::dir_home = $cfg::main_config;
$cfg::dir_home =~ s|/[^/]+$||;
$cfg::dir_web  = $cfg::dir_home.'/web';

unshift @INC, $cfg::dir_home;
unshift @INC, $cfg::dir_web;

my $err_log = 'liqpay_err.log';
my $ok_log = 'liqpay.log';

my $died = 0;
local $SIG{'__DIE__'} = sub {
    die @_ if $^S; # die внутри eval
    $died++;
    eval{ Hard_exit( @_) };
};

sub Exit
{
    print "Content-type: text/html\n\n".$_[0];
    exit;
}

sub Hard_exit
{
    my $err = join ' ', @_;
    my $file = '';
    foreach( "$cfg::dir_home/logs", $cfg::dir_home, '/var/log', '/tmp' )
    {
        open(F, ">>$_/$err_log") or next;
        $file = "$_/$err_log";
        last;
    }
    if( $file )
    {
        eval { 
            debug($err);
            print F ("\n".('=' x 80)."\n");
            Debug->param( -type=>'file', -file=>$file, -nochain=>0 );
            Debug->show; # весь накопленный debug выводим в файл
        };
        if( $@ )
        {  # не удалось записать через Debug, запишем сами (будет менее информативно)
            my @info = caller(0);
            print F "\n\n--- $info[1] line $info[2] ---\n$err";
        }
    }
    # Если был die, то выводим заглушку, иначе возвращаем ошибку
    Exit($died? 'Internal error' : $err);
}

eval "use Debug";
$@ && die $@;

my $ip = $ENV{REMOTE_ADDR};

debug("ip: $ip");

package cfg;
require $cfg::main_config;
package main;

eval "use Db";
$@ && die $@;

Db->new(
    host    => $cfg::Db_server,
    user    => $cfg::Db_user,
    pass    => $cfg::Db_pw,
    db      => $cfg::Db_name,
    timeout => $cfg::Db_connect_timeout,
    tries   => 2, # 2 попытки с интервалом в секунду соединиться
    global  => 1, # создать глобальный объект Db, чтобы можно было вызывать без объекта: Db->sql()
);

my %p = Db->line("SELECT *,UNIX_TIMESTAMP() AS t FROM config ORDER BY time DESC LIMIT 1");
Db->is_connected or die 'No DB connection';
%p or die 'No config in DB';

$cfg::config = $p{data};

eval "
    no strict;
    $cfg::config;
    use strict;
";


my $script = $ENV{SCRIPT_NAME};
my $query;
if( $ENV{REQUEST_METHOD} eq 'POST' )
{
    read(STDIN,$query,$ENV{CONTENT_LENGTH});
    $query .= '&'.$ENV{QUERY_STRING}; # Совмещаем get и post данные
}else
{
    $query .= $ENV{QUERY_STRING};
}

my %F = ();
foreach( split /&/,$query,2 )
{
   my($name,$value) = split /=/,$_,2;
   $name =~ tr/+/ /;
   $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
   $value=~ tr/+/ /;
   $value=~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
   $F{$name} = $value;
}

$query ne '' && debug('Received data:',\%F);

my $sxml = XML::Simple->new() or die 'XML::Simple->new error';
$F{operation_xml} eq '' && Exit('Test Ok');
my($xml, $data); 
eval {
    $xml = decode_base64( $F{operation_xml} );
    $data = $sxml->XMLin( $xml );
};
$@ && Hard_exit('Operation_xml decoding error');
debug($data);

my $signature = encode_base64(sha1($cfg::liqpay_merch_sign.$xml.$cfg::liqpay_merch_sign));
chomp $signature;
$signature eq $F{signature} or Hard_exit('Error signature');

my $status = $data->{status};
$status eq 'wait_secure' && Hard_exit("Wait secure - Ok");
$status =~ /^(success|failure)$/ or Hard_exit("Unknown status: $status");

my $order_id = $data->{order_id};
$order_id =~ /^\d+$/ or Hard_exit('Wrong order id');
my %p = Db->select_line("SELECT * FROM pays WHERE id=? LIMIT 1", $order_id);
%p or Hard_exit("order id $order_id is not found");

# 20 - успешная оплата в платежной системе
$p{category} == 20 && Hard_exit('Duplicate packet. That`s OK');
# 446 - неуспешная оплата в платежной системе
$p{category} == 446 && die 'This pay is marked as fail in my system already';
# 444  - заявка на оплату, 445 - заявка принята платежной системой (если клиент по web вернулся в NoDeny - не обязательно)
($p{category} == 444 || $p{category} == 445) or die 'Internal data mismatch (pay category)';
# имя платежной системы : время : сумма
$p{reason} =~ /^liqpay:\d+:([\d.]+)/ or die 'Internal data mismatch (reason field)';
my $amt = $1;
abs( $amt - $data->{amount} ) < 0.01 or die 'Internal data mismatch (amount)';


if( $status ne 'success' )
{
    Db->do("UPDATE pays SET category=446, time=UNIX_TIMESTAMP() WHERE category IN (444,445) AND id=? LIMIT 1", $order_id);
    Hard_exit('Ok');
}

Db->begin_work or die 'internal error';

my $rows1 = Db->do(
    "UPDATE pays SET cash=?, category=20, time=UNIX_TIMESTAMP() ".
    "WHERE category IN(444,445) AND id=? LIMIT 1",
    $amt, $order_id
);
my $rows2 = Db->do(
    "UPDATE users SET state = IF(balance+(?) >= limit_balance, 'on', state),  balance=balance+(?) ".
    "WHERE id = (SELECT mid FROM pays WHERE id=? LIMIT 1) LIMIT 1",
    $amt, $amt, $order_id
);

if( $rows1 < 1 || $rows2 < 1 || !Db->commit )
{
    Db->rollback;
    die 'internal error';
}

Debug->flush;
debug($data);

$err_log = $ok_log;

Hard_exit('Ok');

