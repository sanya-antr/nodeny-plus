#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package Db;
use strict;
use Time::HiRes qw( gettimeofday tv_interval clock_gettime CLOCK_MONOTONIC );
use Debug;
use DBI;

our $Db;

my %defaults = (
    host    => 'localhost',
    user    => 'root',
    pass    => '',
    db      => 'test',
    timeout => 3,
    tries   => 2,
    global  => 0,
    dsn     => '',
    dbh     => '',
);

sub new
{
 my $cls = shift;
 my %param = @_;
 my $db = {};
 bless $db;
 map{ $db->{$_} = exists $param{$_}? $param{$_} : ref $cls? $cls->{$_} : $defaults{$_} } keys %defaults;
 $db->{dsn} = "DBI:mysql:database=$db->{db};host=$db->{host};mysql_connect_timeout=$db->{timeout}";
 $Db = $db if $db->{global};
 return $db;
}

sub is_connected
{
 my $db = shift;
 $db = $Db if ! ref $db;
 return !defined $db? 0 : $db->{dbh}? 1 : 0;
}

sub connect
{
 my $db = shift;
 $db = $Db if ! ref $db;
 $db->{tries} = int $db->{tries};
 $db->{tries} = 1 if $db->{tries}<1;
 # пробуем $db->{tries} раз соединиться с БД с интервалом 1 сек
 my $i = $db->{tries};
 while( 1 )
 {
    $db->{dbh} = DBI->connect($db->{dsn}, $db->{user}, $db->{pass},{ PrintError=>0, RaiseError=>0, AutoCommit=>1 });
    $db->{dbh} && last;
    --$i or last;
    sleep 1;
 }
 if( $db->{dbh} )
 {
    debug('Connecting to',$db->{dsn},': OK');
    $db->{dbh}->do("SET NAMES 'utf8' COLLATE 'utf8_general_ci'");
    #$db->{dbh}->do("SET NAMES 'binary' COLLATE 'binary'");
 }
  else
 {
    debug('error','No DB connection,',$db->{dsn},': ',$DBI::errstr);
 }
}

sub disconnect
{
 my $db = shift;
 $db = $Db if ! ref $db;
 $db->{dbh} = 0;
}

sub sql
{
 my $db = shift;
 $db = $Db if ! ref $db;

 my $param = shift;
 my $it = Db::result->new( ref $param? $param : { sql=>$param, param=>[@_] } );

 $it->{db} = $db;
 my $sql = $it->{sql};
 $param  = $it->{param};

 $db->is_connected or $db->connect;
 if( !$db->is_connected )
 {
    debug('error', 'mysql is disconnected');
    my $error_tm = clock_gettime(CLOCK_MONOTONIC);
    $db->{error_tm} ||= $error_tm;
    if( ($error_tm - $db->{error_tm}) > 300 )
    {
        tolog('error', 'No DB connection');
        $db->{error_tm} = 0;
    }
    return $it;
 }
 $db->{error_tm} = 0;

 if( !$sql )
 {
    debug('error', 'sql is required');
    return $it;
 }

 my $show_sql = $sql;
 if( ref $param eq 'ARRAY' && scalar @$param > 0 )
 {
    my @q_param = map{ $db->{dbh}->quote($_) } @$param;
    $show_sql =~ s|\?|shift @q_param|eg;
 }

 my $tm_sql = [gettimeofday];
 my $sth  = $it->{sth}  = $db->{dbh}->prepare($sql);
 my $ok   = $it->{ok}   = $sth->execute(ref $param eq 'ARRAY'? @$param : ());
 my $rows = $it->{rows} = $sth->rows;
 $tm_sql = tv_interval($tm_sql);

 my $time = $tm_sql>0.00009? sprintf("%.4f",$tm_sql) : sprintf("%.8f",$tm_sql);

 my $comment = $it->{comment};
 $comment .= "\n" if $comment;
 $comment .= $show_sql."\n"."Строк: $rows. Время выполнения sql: $time сек";

 if( $ok )
 {
    debug($comment);
 }
  else
 {
    debug('pre','error', $DBI::errstr,"\n",{ sql=>$sql, param=>$param },"\n",$comment);
    $db->disconnect;
 }
 return $it;
}

# --- Выборка одной строки ---

sub line
{
 my $db = shift;
 my $dbres = $db->sql(@_);
 $dbres->{sth} or return ();
 my $p = $dbres->{sth}->fetchrow_hashref;
 return $p? %$p : ();
}

sub select_line
{
 return line(@_);
}

sub do
{
 my $db = shift;
 my $dbres = $db->sql(@_);
 return $dbres->rows;
}

sub begin_work
{
 my $db = shift;
 $db = $Db if ! ref $db;
 debug('start transaction');
 return $db->{dbh}->begin_work();
}

sub commit
{
 my $db = shift;
 $db = $Db if ! ref $db;
 debug('commit');
 return $db->{dbh}->commit();
}

sub rollback
{
 my($db,$msg) = @_;
 $db = $Db if ! ref $db;
 debug('warn', 'rollback'.($msg ne '' && " ($msg)"));
 return $db->{dbh}->rollback();
}

sub do_all
{
 my($db, @sqls) = @_;
 if( !$db->begin_work )
 {
    debug('warn', 'Db->begin_work fail');
    return 0;
 }
 foreach my $sql( @sqls )
 {
    if( $db->do(@$sql) < 1 )
    {
        $db->rollback("fail: $sql->[0]");
        return 0;
    }
 }
 $db->commit && return 1;
 $db->rollback('commit error');
 return 0;
}

sub ok
{
 return Db::result->ok;
}

sub rows
{
 return Db::result->rows;
}

sub dbh
{
 my $db = shift;
 $db = $Db if ! ref $db;
 return $db->{dbh};
}

sub filtr
{
 shift;
 local $_=shift;
 utf8::is_utf8($_) && utf8::encode($_);
 s|\\|\\\\|g;
 s|'|\\'|g;
 s|"|\\"|g;
 s|\r||g;
 return $_;
}

# -------------------------------------------

package Db::result;
use strict;
use Time::HiRes qw( gettimeofday tv_interval );
use Debug;
use DBI;

my $Dbres;

sub new
{
 shift;
 $Dbres = shift;
 $Dbres->{ok} = 0;
 $Dbres->{rows} = -1;
 bless $Dbres;
}

sub ok
{
 my $dbres = shift;
 $dbres = $Dbres if ! ref $dbres;
 return $dbres->{ok};
}

sub rows
{
 my $dbres = shift;
 $dbres = $Dbres if ! ref $dbres;
 return $dbres->{rows};
}

sub sth
{
 my $dbres = shift;
 $dbres = $Dbres if ! ref $dbres;
 return $dbres->{sth};
}

sub insertid
{
 my $dbres = shift;
 $dbres = $Dbres if ! ref $dbres;
 return $dbres->{sth}->{mysql_insertid};
}

sub line
{
 my $dbres = shift;
 $dbres = $Dbres if ! ref $dbres;
 $dbres->{row} = undef;
 $dbres->{sth} or return ();
 my $p = $dbres->{row} = $dbres->{sth}->fetchrow_hashref;
 return $p? %$p : ();
}

sub get_line
{
 return line(@_);
}

1;

__END__

Если методы запускаются без объекта, то берется внутренний глобальный объект

    2 формата вызова:
1) Db->sql( sql, параметры для плейсхолдеров )
2) Db->sql({ параметры })

    Если необходима выборка только одной строки:

my %p = Db->line( параметры );

Хеш %p пустой если:
1) пустая выборка
2) произошла ошибка (неверный sql, дисконнект БД,...)

Чтобы уточнить: Db->ok возвращает 1, если не было ошибок

    Выборка одной строки:

my %p = Db->line("SELECT * FROM users WHERE id=? AND grp=?", $id, $grp);
print %p? "$p{name}, $p{fio}" : Db->ok? 'пустая выборка' : 'внутренняя ошибка';

    Выборка нескольких строк:

my $db = Db->sql("SELECT id, name FROM users WHERE field=?", $unfiltered_field);
while( my %p = $db->line )
{
    print "$p{id} = $p{name}\n";
}

    Выборка нескольких строк с иным форматом вызова:

my $db = Db->sql(
    sql     => "SELECT * FROM tbl WHERE field=? AND val=?",
    param   => [ $filed, $val ],
    comment => 'Выборка номер 2',
);
while( my %p = $db->line ) { ... }

    Update/Insert:
 
my $rows = Db->do("UPDATE websessions SET uid=?, role=? WHERE ses=? LIMIT 1", $id, $role, $ses);
$rows>0 or Error('!'); # не делайте $rows or Error() т.к. rows может = -1


    Выполнение нескольких запросов в транзакции:

Db->do_all(
    [$sql1, $param1, $param2 ],
    [$sql2, $param3 ],
);

Проверяется, что каждый запрос затронул как минимум 1 строку. Внимание! Если запрос выполнился,
но не затронул ни одну строку (ни одного совпадение по условию WHERE), то будет откат транзакции.

--- Полный пример ---

Db->new(
    host    => $cfg::Db_server,
    user    => $cfg::Db_user,
    pass    => $cfg::Db_pw,
    db      => $cfg::Db_name,
    timeout => $cfg::Db_mysql_connect_timeout,
    tries   => 3, # попыток с интервалом в секунду соединиться
    global  => 1, # создать глобальный объект Db, чтобы можно было вызывать абстрактно: Db->sql()
);

Db->is_connected or die 'No DB connection';

my $ok = Db->do_all(
    ["UPDATE ... WHERE ...", $param1, $param2 ],
    ["UPDATE ... WHERE ...", $param3 ],
    ["UPDATE ... WHERE ...", $param4 ],
);

$ok or print "Как минимум 1 запрос (или commit) не выполнился - все sql откатаны rollback-ом";

