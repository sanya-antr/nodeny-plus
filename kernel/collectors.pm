#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::collectors;
use strict;
use Debug;
use Db;
use nod::tasks;
use threads;
use threads::shared;
use Time::localtime;


our @ISA = qw{kernel};

$cfg::_tbl_name_template = '%s_%s_%s';

# Таблица детализации трафика
$cfg::_slq_create_Ztraf_tbl.=<<SQL;
(
  `uid` int(10) unsigned NOT NULL DEFAULT '0',
  `time` int(10) unsigned NOT NULL DEFAULT '0',
  `bytes` int(10) unsigned NOT NULL DEFAULT '0',
  `direction` tinyint(4) unsigned NOT NULL DEFAULT '0',
  `class` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `uip` int(10) unsigned NOT NULL DEFAULT '0',
  `ip` int(10) unsigned NOT NULL DEFAULT '0',
  `port` smallint(5) unsigned NOT NULL DEFAULT '0',
  `proto` smallint(5) unsigned NOT NULL DEFAULT '0',
  KEY `time` (`time`)
) ENGINE=MyISAM;
SQL

# Таблица трафика
$cfg::_slq_create_Xtraf_tbl = <<SQL;
(
  `uid` mediumint(9) NOT NULL default '0',
  `time` int(11) unsigned NOT NULL default '0',
  `class` tinyint(4) NOT NULL default '0',
  `in` bigint(20) unsigned NOT NULL default '0',
  `out` bigint(20) unsigned NOT NULL default '0',
  KEY `uid` (`uid`),
  KEY `time` (`time`)
) ENGINE=MyISAM;
SQL

my $M;

sub start
{
    my(undef, $single, $param) = @_;

    $M = $param;
    bless $M;

    $M->{collectors}  = {};
    $M->{start_collect} = 0;

    my $i = 0;
    foreach my $collector( @{$M->{list}} )
    {
        my $collector_pkg = __PACKAGE__.'::'.$collector->{type};
        tolog("loading $collector_pkg.pm");
        eval "use $collector_pkg";
        if( $@ )
        {
            debug('error', $@);
            next;
        }
        share $collector->{step};
        share $collector->{result};
        $collector->{pkg} = $collector_pkg;
        threads->create( \&{$collector->{pkg}.'::new'}, $collector ) or die 'cannot create thread';
        $M->{collectors}{$i++} = $collector;
    }

    nod::tasks->new(
        task         => \&load_users,
        period       => 60,
        first_period => 0,
    );

    nod::tasks->new(
        task         => \&chk_collectors,
        period       => 2,
        first_period => 2,
    );
}


sub chk_collectors
{
    # --- Запуск коллекторов (их обработчиков)---
    if( $M->{start_collect} < kernel->Time )
    {
        my %p = Db->line("SELECT unix_timestamp() AS t");
        %p or return;
        my $time = $p{t};

        # следущий запуск коллекторов будет в
        $M->{start_collect} = kernel->Time + $M->{period};

        my $t = localtime($time);
        my($day_now,$mon_now,$year_now) = ($t->mday,$t->mon,$t->year);
        my $traf_tbl_name = sprintf $cfg::_tbl_name_template, $year_now+1900, $mon_now+1, $day_now;

        # Создадим таблицы трафика
        Db->do("CREATE TABLE IF NOT EXISTS X$traf_tbl_name $cfg::_slq_create_Xtraf_tbl");
        Db->do("CREATE TABLE IF NOT EXISTS Z$traf_tbl_name $cfg::_slq_create_Ztraf_tbl");

        debug('Опрос обработчиков коллекторов');
        foreach my $i( keys %{$M->{collectors}} )
        {
            my $collector = $M->{collectors}{$i};
            if( $collector->{step} )
            {
                debug("Коллектор $collector->{type}:$collector->{addr} пока не дал ответ, новый запрос не создаем");
                next;
            }
            $collector->{tm_start} = $time;
            $collector->{traf_tbl_name} = $traf_tbl_name;
            $collector->{step} = 1;
        }
    }

    foreach my $i( keys %{$M->{collectors}} )
    {
        my $collector = $M->{collectors}{$i};
        $collector->{step} == 2 or next;
        debug("Получили данные от $collector->{type}:$collector->{addr}");
        $M->parse_traf( $collector );
        $collector->{step} = 0;
    }
}

sub parse_traf
{
    my(undef, $collector) = @_;

    my $debug_lines = 10;
    my $verbose = $cfg::verbose > 1;
    $verbose && debug( substr $collector->{result},0,6000 );

    my $counters = {
        tm_start    => kernel->Time,
        lines       => 0,               # количество строк входного дампа
        size        => length($collector->{result}),
        err_lines   => 0,               # количество строк дампа, которые не были интерпретированы как инфо о трафике
        no_usr_traf => 0,               # количество строк дампа, которые не получилось ассоциировать ни с одним из клиентов
    };

    # время старта опроса текущего коллектора
    my $tm_collector_start = $collector->{tm_start};
    my $traf_tbl_name = $collector->{traf_tbl_name};

    my $insert_into_z_tbl = "INSERT DELAYED INTO Z$traf_tbl_name (uid,time,bytes,class,direction,uip,ip,port,proto) VALUES";
    my $insert_into_traflost = "INSERT INTO traflost (time,traf,collector,ip1,ip2) VALUES";

    my $traf = {};

    foreach my $traf_line( split /\n/, $collector->{result} )
    {
        $counters->{lines}++;
        $traf_line =~ s/^\s+//;
        $traf_line eq '' && next;
        my($ip1, $ip2, $pkt, $bytes, $port1, $port2, $proto, $direction) = split /\s+/, $traf_line;

        if( $ip1 !~ /^\d+\.\d+\.\d+\.\d+$/o )
        {
            $counters->{err_lines}++;
            next;
        }

        $port2 = $port1 if $proto==1; # в icmp тип пакета в src_port
        $port2 = int $port2;
        $proto = int $proto;

        if( $direction == 2 )
        {   # трафик к клиенту
            ($ip2,$ip1,$port2,$port1) = ($ip1,$ip2,$port1,$port2);
        }
         else
        {
            $direction = 1;
        }

        # ip1: usr , ip2: удаленный ip
        my $uid = $M->{ips}{$ip1};
        if( !$uid )
        {
            $counters->{no_usr_traf}++;
            if( $verbose && $debug_lines-- > 0 )
            {
                debug("$ip1 не принадлежит ни одному клиенту в базе");
                $M->long_sql($insert_into_traflost, "($tm_collector_start,0,INET_ATON('$ip1'),INET_ATON('$ip2'))");
            }
            next;
        }

        my($i1,$i2,$i3,$i4) = split /\./,$ip2;
        my $ip_raw = pack('CCCC', $i1,$i2,$i3,$i4);

        my $cls = 1;
        if( $M->{nets}{$i3} )
        {
            foreach my $net( @{$M->{nets}{$i3}} )
            {
                if( ($ip_raw & $net->{mask}) eq $net->{net} && (!$net->{port} || $net->{port}==$port2) )
                {
                    $cls = $net->{cls};
                    last;
                }
            }
        }

        if( $verbose && $debug_lines-- > 0 )
        {
            debug(
                "input: $traf_line\n".
                " uid: $uid. $ip1 ".($direction == 2? '<-' : '->')." $ip2. Cls: $cls"
            );
        }

        $traf->{$uid} ||= {};
        $traf->{$uid}{$cls} ||= {};
        $traf->{$uid}{$cls}{$direction} += $bytes;

        # uid, time, bytes, class, direction, uip, ip, port, proto
        $M->long_sql( $insert_into_z_tbl, "($uid,$tm_collector_start,$bytes,$cls,$direction,INET_ATON('$ip1'),INET_ATON('$ip2'),$port2,$proto)" );
    }
    $M->long_sql($insert_into_z_tbl, '');
    $M->long_sql($insert_into_traflost, '');

    $counters->{tm_parse} = kernel->Time - $counters->{tm_start};

    my $insert_into_x_tbl = "INSERT INTO X$traf_tbl_name (uid,class,time,`in`,`out`) VALUES";
    # запишем нулевой трафик клиенту с id = 0:
    #   1) если никто не качает - будет видно, что срез был
    #   2) для выборки графика по конкретному клиенту нужны срезу, в которых он ничего не скачивал
    foreach my $cls( 1..4 )
    {
        $M->long_sql( $insert_into_x_tbl, "(0,$cls,$tm_collector_start,0,0)" );
    }
    foreach my $uid( keys %$traf )
    {
        my $t = $traf->{$uid};
        my $sql = '';
        my @sql = ();
        foreach my $cls( 0..4 )
        {
            my $in  = int $t->{$cls}{2};
            my $out = int $t->{$cls}{1};
            ($in+$out) or next;
            $M->long_sql( $insert_into_x_tbl, "($uid,$cls,$tm_collector_start,$in,$out)" );
            $cls or next;
            $sql .= ", in$cls=in$cls+?, out$cls=out$cls+?";
            push @sql, $in, $out;
        }
        # actual = 0 заставит пересчитать баланс
        Db->do("UPDATE users_trf SET actual=0 $sql WHERE uid=? LIMIT 1", @sql, $uid);
    }
    $M->long_sql( $insert_into_x_tbl, '' );
    $counters->{tm_save_traf} = kernel->Time - $counters->{tm_start};

    debug($counters);
}

# Формирует длинный sql: INSERT ... VALUES (...),(...),(...)
# Пример:
#   $M->long_sql( "INSERT INTO tbl (key,val) VALUES", "(1,'yes')" );
#   $M->long_sql( "INSERT INTO tbl (key,val) VALUES", "(2,'no')" );
# Пустой 2й параметр заставляет непосредственно выполнить длинный sql
#   $M->long_sql( "INSERT INTO tbl (key,val) VALUES", '' );
# Если в процессе будет достигнут лимит на длину sql, он будет выполнен и
# продолжится дальнейшее накопление, возможно многократно.

sub long_sql
{
    my(undef, $sql, $sql_param) = @_;
    if( $sql_param ne '' )
    {
        $M->{long_sql}{$sql} .= $M->{long_sql}{$sql}? ",$sql_param" : $sql.$sql_param;
    }
    my $sql_len = length $M->{long_sql}{$sql};
    if( ($sql_len && $sql_param eq '') || $sql_len > 10000 )
    {
        my $dbh = $Db::Db->{dbh};
        my $rows = $dbh->do( $M->{long_sql}{$sql} );
        debug("$sql ... (rows: $rows)");
        delete $M->{long_sql}{$sql};
    }
}

sub load_users
{
    my $db = Db->sql("SELECT uid,INET_NTOA(ip) AS ip FROM ip_pool WHERE uid<>0");
    Db->ok or return;
    $M->{ips} = {};
    while( my %p = $db->line )
    {
        $M->{ips}{$p{ip}} = $p{uid};
    }
    my $db = Db->sql("SELECT * FROM nets WHERE priority>0 ORDER BY priority");
    Db->ok or return;
    $M->{nets} = {};
    while( my %p = $db->line )
    {
        $p{net} =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)(\/\d+)?$/ or next;
        my $net_raw = pack('CCCC',$1,$2,$3,$4);
        my $oct3 = $3;
        my $mask = 32;
        if( defined $5 )
        {
            $mask = $5;
            $mask =~ s|/||;
            $mask = 32 if $mask>32;
        }
        my $mask_raw = pack('B32', 1 x $mask, 0 x (32-$mask));
        my $port = $p{port};
        my $cls  = $p{class};
        # Кол-во вариантов 3го октета (например, для сети /16 вариантов 256)
        my $i = $mask>23? 1 : $mask<17? 256 : 2**(24-$mask);
        while( $i-- )
        {
            $M->{nets}{$oct3} ||= [];
            push @{ $M->{nets}{$oct3} }, {
                net  => $net_raw,
                mask => $mask_raw,
                port => $port,
                cls  => $cls,
            };
            $oct3++;
        }
    }
}

1;