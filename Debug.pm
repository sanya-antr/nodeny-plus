#!/usr/bin/perl
package Debug;
=head1 INFO

Модуль логов/дебага в web/консоль/файл.

Автор: Volik Stanislav ( max.begemot@gmail.com )

Примеры:

debug('Все ок');
debug('error', 'Ошибка!');
debug('warn', 'Предупреждение');
debug('Dump переменной $obj: ', $obj, ' - вот так!');
debug(\%hash);
Debug->add('Все ок'); # синоним debug('Все ок');

Для web-приложений:

Debug->show;                            # рендеринг дебага в html-вид
Debug->show(1);                         # рендеринг только последней строки debug-а

Для консольных приложений:

Debug->param(
    -type => 'console',                 # дебаг не сохраняется для последующего рендеринга, а выводится в консоль
    -drop_chain => 1,                   # не выводить цепочку подпрограмм для каждого сообщения
);

Для записи в файл:

Debug->param(
    -type => 'file',
    -file => 'debug.txt',
);

Debug->param( -only_log => 1 );         # заставит вести дебаг только при вызове подпрограммы tolog(),
                                        # debug() будет игнорироваться 

--- Сложный пример ---

debug(...);
...
tolog(...);
...
eval{ ... };
if( $@ )
{
    debug($@);
    Debug->param( -type=>'file', -file=>'debug.txt' );
    # вывод в файл ранее накопленного debug-а
    Debug->show;
    exit;
}

--- Пример нескольких дебаг-объектов ---

my $main_debug = Debug->new;
my $detail_debug = Debug->new;

$main_debug->add('start');
$detail_debug->add('object info', $object);

------------------------
--- Многопоточность  ---
------------------------

use threads;
use threads::shared;
use Debug;

# Делаем глобальный объект Debug расшаренным между потоками
Debug->threaded;

threads->create( \&thread1 );
threads->create( \&thread2 );

=cut

use strict;
no warnings 'layer';
use base qw( Exporter );
use Time::HiRes qw( gettimeofday tv_interval );
use Time::localtime;
use Data::Dumper;
use IO::Handle;

our @EXPORT = qw( debug tolog );

my $css=<<CSS;
<style type='text/css'>
<!--
.debug_tbl {border:1px solid #666; border-collapse: collapse; color:#000; font-size:8pt; font-family: Tahoma,sans-serif; margin: 0 auto;}
.debug_tbl td {padding: 2px 6px 2px 6px; border:1px solid #fff }
.debug_head {background-color:#666; color: #fff; text-align:center}
.debug_row1 {background-color:#eeeeee}
.debug_row2 {background-color:#e0e0e0}
.debug_row_err {background-color:#ffe0e0}
.debug_row_warn {background-color:#ffffff; color:#a00000;}
.debug_row_bold {font-weight:bold}
.debug_chain_tbl {border:0; width:100%; color:#000; font-size:8pt; background-color:#fff}
.debug_chain_tbl td {border:0;}
.debug_a {display:inline-block; padding:3px; border:1px solid #c0c0c0; background-color:#d0d5e0; text-decoration:none; color:#000090}
-->
</style>
<script type='text/javascript'>
function debug_show_block(id){
 var e = document.getElementById('a_' + id);
 if( e.style.display == 'none' ){e.style.display = '';} else {e.style.display = 'none';}
 var e = document.getElementById('b_' + id);
 if( e.style.display == 'none' ){e.style.display = '';} else {e.style.display = 'none';}
}
</script>
CSS

my %row_type = (
    'error'     => 'debug_row_err',
    'warn'      => 'debug_row_warn',
    'bold'      => 'debug_row_bold',
    'disabled'  => 'debug_row_disabled',
    'head'      => 'debug_head',
);

my $debug ||= Debug->new;

sub new
{
 shift;
 my $it = {};
 $it->{data} = [];
 $it->{tm_start} = [gettimeofday];
 $it->{id} = $it->{tm_start}[1];
 $it->{-drop_chain} = 0;
 $it->{-lines} = 0;
 $it->{-type} = 'web';
 bless $it;
 $it->param(@_);
 return $it;
}

sub param
{
 my $it = shift;
 $it = $debug if ! ref $it;
 my %param = @_;
 foreach( keys %param )
 {
    defined $param{$_} or next;
    $it->{$_} = $param{$_};
 }
 return $it->{$_[0]};
}

sub self
{
 my $it = shift;
 return ref $it? $it : $debug;
}

sub threaded
{
 my $it = shift;
 my $global = ! ref $it;
 $it = $debug if $global;
 $it->{threaded} && return $it;
 eval "use threads; use threads::shared";
 $@ && return;
 $it->{threaded} = 1;
 $it = shared_clone $it;
 $debug = $it if $global;
 return $it;
}

sub flush
{
 my $it = shift;
 $it = $debug if ! ref $it;
 {
    $it->{threaded} && lock $it;
    $it->{data} = [];
    $it->{-lines} = 0;
 }
}

sub add
{
 my $it = shift;
 $it = $debug if ! ref $it;
 $it->{-only_log} && return;
 return $it->_add(@_);
}

sub insert
{
 my $it = shift;
 $it = $debug if ! ref $it;
 {
    $it->{threaded} && lock $it;
    $it->{-only_log} && return;
    my $line = $it->_form_line(@_);
    $it->{-type} eq 'web' or return;
    unshift @{$it->{data}}, $line;
 }
}

sub debug
{
 # Вызван как метод объекта или как глобальная экспортированная функция
 my $it = ref $_[0] eq 'Debug'? shift : $debug;
 return $it->add(@_);
}

sub tolog
{
 my $it = ref $_[0] eq 'Debug'? shift : $debug;
 return $it->_add(@_);
}

sub errors
{
 my $it = shift;
 $it = $debug if ! ref $it;
 return $it->{errors};
}

sub _add
{
 my $it = shift;
 {
    $it->{threaded} && lock $it;
    my $line = $it->_form_line(@_);
    $it->{-type} eq 'web' or return;
    push @{$it->{data}}, $line;
 }
}

sub _form_line
{
 my $it = shift;
 my $type = '';
 while( $_[0] =~ /^(warn|error|disabled|bold|head|pre|dump)$/ )
 {
    $_[0] eq 'error' && $it->{errors}++;
    $type .= ' '.shift;
 }
 my $msg = '';
 foreach my $m( @_ )
 {
    if( !ref $m )
    {
        $msg .= ' ' if $msg;
        $msg .= $m;
        next;
    }

    $msg .= "\n" if $msg;

    # Хеши красиво оформляем, но только если в них нет вложенных ссылок
    if( ref $m eq 'HASH' && keys %$m )
    {
        my $tmp_msg = '';
        my $max_len = 0;
        foreach my $key( keys %$m )
        {
            if( ref $m->{$key} )
            {
                $tmp_msg = 'no';
                last;
            }
            $max_len = length $key if length $key > $max_len;
        }
        $max_len++;
        if( !$tmp_msg )
        {
            foreach my $key( sort{$a cmp $b} keys %$m )
            {
                my $spaces = $max_len - length $key;
                $spaces = $spaces>0? ' ' x $spaces : '';
                my $val = $m->{$key};
                if( ! defined $val )
                {
                    $val = 'undef';
                }
                 elsif( $val =~ /'|\n/ )
                {
                    $val =~ s/"/\\"/g;
                    $val =~ s/\r//g;
                    $val =~ s/\n/\\n/g if length $val<120;
                    $val = "\"$val\"";
                }
                 else
                {
                    $val =~ s/'/\\'/g;
                    $val =~ s/\r//g;
                    $val = "'$val'";
                }
                $msg .= "  $key$spaces = $val\n";
            }
            chomp $msg;
            next;
        }
    }

    my $dump = Data::Dumper->new([$m],['$VAR1']);
    $dump->Indent(1);
    $dump = $dump->Dump;
    $dump =~ s/^\$VAR\d+\s*=\s*//s;
    $msg .= $dump;
 }

 my $sub_chain = _sub_chain();

 $it->{-type} eq 'web' or $it->_print($sub_chain, $msg);
 $it->{-lines}++ > 1000 && $it->flush;
 my $line = [ $sub_chain, $msg, $type, sprintf("%.6f",tv_interval $it->{tm_start}) ];
 $line = shared_clone($line) if $it->{threaded};
 return $line;
}

sub _print
{
 my($it, $sub_chain, $msg) = @_;
 my $chain = '';
 if( $it->{-drop_chain} )
 {
    pop @$sub_chain foreach( 0..$it->{-drop_chain} );
 }
 foreach my $c( @$sub_chain )
 {
    $chain .= "$c->[1]($c->[0]) ";
 }
 chop $chain;
 if( $it->{-type} eq 'console' )
 {
    $chain = sprintf("%.6f",tv_interval $it->{tm_start}).': '.$chain;
    $msg = "\033[1;30m"."[$chain]"."\033[0m"."\n".$msg if ! $it->{-nochain};
    $msg .= "\n" if ! $it->{-only_log};
    $msg .= "\n";
    eval{
        my $io = IO::Handle->new();
        $io->fdopen(fileno(STDOUT),'w') or die;
        $io->printflush($msg);
        $io->close;
    };
    $@ && print $msg;
    return;
 }

 $it->{-file} ne '' or return;
 $msg = "[$chain]\n$msg" if ! $it->{-nochain};
 open(F, ">>$it->{-file}") or return;
 my $t = localtime();
 $msg = sprintf("%02d.%02d.%04d %02d:%02d:%02d %s\n",$t->mday,$t->mon+1,$t->year+1900,$t->hour,$t->min,$t->sec,$msg);
 print F $msg;
 close(F);
}

sub _sub_chain
{
 my $sub_chain = [];
 my $level = 0;
 while( 1 )
 {
   my(undef,$filename,$line) = caller($level);
   my(undef,undef,undef,$subroutine) = caller($level+1);
   last if $level++>20 || !$line;
   $subroutine  =~ s|^.+::||;           # уберем имя пакета
   $subroutine  =~s|\(eval ?\d?\)||;# && next;
   $filename    =~ s|.*/||;             # уберем каталоги
   $filename eq 'Debug.pm' && next;
   $filename .= '::'.$subroutine if $subroutine;
   unshift @$sub_chain, [$line,$filename];
 }
 return $sub_chain;
}


sub dump
{
 my($it,$data) = @_;
 utf8::decode($data);
 $Data::Dumper::Indent = 0;
 return Dumper($data);
}

sub code
{
 my $it = shift;
 $it = $debug if ! ref $it;
 return Debug->dump($it);
}


# --- Рендеринг в html-вид ---

sub show
{
 my $it = shift;
 my $row_show = int shift; # сколько последних строк рендерим
 $it = $debug if ! ref $it;
 my $type_out = $it->{-type};
 if( !$row_show )
 {
    
    $it->{-type} = 'web';
    $it->add("Elapsed time: ".sprintf("%.6f",tv_interval $it->{tm_start})." sec");
 }

 my $out = $css;
 my @rows = ('debug_row1','debug_row2');
 my $tbl = !$row_show && "<tr class='debug_head'><td></td><td>Type/sec</td><td>Sub</td><td>Debug</td></tr>";

 my @it = @{$it->{data}};
 @it = @it[-$row_show..-1] if $row_show>0;

 my $chain_id = 0;
 foreach my $line( @it )
 {
    my($sub_chain, $msg, $type, $time) = @$line;
    if( $type_out ne 'web' )
    {
        $it->_print($sub_chain, $msg);
        next;
    }

    $msg = _filtr($msg);
    $msg =~ s|\n\r?|<br>|g;
    $msg = "<pre>$msg</pre>" if $type =~ s/ pre//;

    $type =~ s/ //;
    my $row  = $row_type{$type} || $rows[0];
    my $chain = '';
    my $last_chain = '';
    $chain_id++;
    my $chain_id_dom = 'debug_'.$it->{id}.'_'.$chain_id;
    foreach my $c( @$sub_chain )
    {
        $chain .= "<tr><td>$c->[0]</td><td>$c->[1]</td><tr>";
        $last_chain = "$c->[0] $c->[1]";
    }
    $chain = "<table class='debug_chain_tbl' style='display:none' id='a_$chain_id_dom'>$chain</table>";
    $chain .= "<div id='b_$chain_id_dom'>$last_chain</div>";
    $tbl .= qq{<tr class='$row'><td><a class='debug_a' href='javascript:debug_show_block("$chain_id_dom")'>+</a></td><td>$time</td><td>$chain</td><td>$msg</td></tr>};
    @rows = reverse @rows;
 }
 return $out."<table class='debug_tbl'>$tbl</table>";
}

sub _filtr
{
 local $_;
 my @rez=();
 while( $_ = shift )
 {
   s|&|&amp;|g;
   s|<|&lt;|g;
   s|>|&gt;|g;
   s|'|&#39;|g;
   push @rez, $_;
 }
 return !@rez? '' : @rez<2? $rez[0] : @rez;
}


1;
