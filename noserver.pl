#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package noserver;
use strict;
use FindBin;
use lib $FindBin::Bin;
use nod;

# Sql выборки всех авторизованных клиентов, которым не запрещен доступ и у которых подключена услуга с тегом `inet`

my $sql_get_auth_usr = <<SQL;
    SELECT u.id, a.ip FROM (
        SELECT INET_NTOA(i.ip) AS ip FROM users u JOIN ip_pool i ON i.uid=u.id WHERE u.lstate=1 
            UNION
        SELECT ip FROM auth_now
    ) a 
        JOIN ip_pool i ON INET_ATON(a.ip)=i.ip
        JOIN users u ON i.uid=u.id
    WHERE u.state='on' AND 
        EXISTS (SELECT uid FROM v_services WHERE tags LIKE '%,inet,%' AND uid=u.id)
SQL

$sql_get_auth_usr =~ s/^ +| *\n */ /g;

my $M = noserver->new(
    file_cfg => 'sat.cfg',
    file_log => 'noserver.log',
);

$M->{usr_hash} = {};
$M->{users}    = {};
$M->{traf}     = {};
$M->{nets}     = {};

$M->Start;

foreach( 0..59 )
{
    $M->Is_terminated && exit;
    Db->connect;
    Db->is_connected && last;
    sleep 1;
}

# Хранение трафика в последние X срезов.
# Более логичным было бы хранение в ввиде:
# [  [ time1 , { uid1 => traf1, uid2 => traf2 } ], [ time2, ...], .... ]
# Но поскольку часто будет идти перебор по времени, то для ускорения разбил на 2 массива: времени и трафика
$M->{traf_time} = [];
$M->{traf_values} = [];

unshift @cfg::noserver_plg, 'nofire';
foreach my $plg( @cfg::noserver_plg )
{
    $plg = "noserver::$plg";
    tolog("loading $plg.pm");
    eval "use $plg";
    $@ && die $@;
}

# Обновления списка `какие сети в каких направлениях`
$M->Task_add(
    task         => \&load_nets,
    period       => 5*60,
    first_period => 0,
);

# С таким периодом будут фиксироваться изменения данных клиентов
$M->Task_add(
    task         => \&load_usr_info,
    period       => 5,
    first_period => 1,
);

# Сбор общего трафика каждого клиента
$M->Task_add(
    task         => \&load_usr_traf,
    period       => 20,
    first_period => 3,
);

# С таким периодом будет запуск накопленных правил в фаерволе
$M->Task_add(
    task         => \&proc_fw,
    period       => 5,
    first_period => 5,
);

# При изменении данных клиента, например при его блокировке, состояние в фаерволе
# будет изменено от 0 сек до (период load_usr_info + период load_usr_traf) сек


$M->fw_flush;

$M->Task_run;

exit;

# -------------------------------------

sub fingerprint
{
    my($M, $data) = @_;
    return( join '', map{ $_."\0".$data->{$_}."\0" } sort{ $a cmp $b } keys %$data );
}

sub proc_fw
{
    my($M, $task) = @_;
    my %all_uid = map{ $_ => 1 } keys %{$M->{usr_hash}};
    foreach my $uid( keys %{$M->{users}} )
    {
        delete $all_uid{$uid};
        my $new_fingerprint = $M->fingerprint($M->{users}{$uid});
        my $old_fingerprint = $M->{usr_hash}{$uid};
        if( $old_fingerprint )
        {
            $new_fingerprint eq $old_fingerprint && next;
            debug("Данные uid $uid изменились - переподключаем");
            $M->fw_usr_off($uid);
        }
        $M->{usr_hash}{$uid} = $new_fingerprint;
        $M->fw_usr_on($uid);
    }
    foreach my $uid( keys %all_uid )
    {
        delete $M->{usr_hash}{$uid};
        $M->fw_usr_off($uid);
    }

    $M->Event_run('fw_run', $M->{fw});
    $M->fw_run;
}

sub load_usr_info
{
    my($M, $task) = @_;
    my $db = Db->sql( $sql_get_auth_usr );
    $db->ok or return;
    $M->{users} = {};
    while( my %p = $db->line )
    {
        my $uid = $p{id};
        if( exists $M->{users}{$uid} )
        {
            $M->{users}{$uid}{ip} .= ",$p{ip}";
            next;
        }
        $p{speed_in1}  = 0;#10**8;
        $p{speed_out1} = 0;#10**8;
        $M->{users}{$uid} = \%p;
    }
    $M->Event_run('load_usr_info');
}

sub load_usr_traf
{
    my($M, $task) = @_;
    my $db = Db->sql(
        "SELECT SQL_BUFFER_RESULT *,SUM(in1+in2+in3+in4) AS traf_in, SUM(out1+out2+out3+out4) AS traf_out ".
        "FROM users_trf GROUP BY uid"
    );
    $db->ok or return;
    $M->{traf} = {};
    my $traf_sum = {};
    while( my %p = $db->line )
    {
        my $uid = $p{uid};
        $M->{traf}{$uid} = \%p;
        $traf_sum->{$uid} = $p{traf_in} + $p{traf_out};
    }

    # Храним статистику за последние 12 часов
    my $time_remove = int($M->Time) - 12*60*60;
    while( exists $M->{traf_time}[0] && $M->{traf_time}[0] < $time_remove )
    {
        shift @{$M->{traf_time}};
        shift @{$M->{traf_values}};
    }

    push @{$M->{traf_time}}, int($M->Time);
    push @{$M->{traf_values}}, $traf_sum;

    $M->Event_run('load_usr_traf');
}

sub load_nets
{
    my($M, $task) = @_;
    my $db = Db->sql("SELECT SQL_BUFFER_RESULT * FROM nets WHERE priority>0 ORDER BY priority");
    $db->ok or return;
    # предыдущий список сетей
    my $nets = $M->{nets};
    $M->{nets} = {};
    # добавим в фаервол сети, которые изменились
    while( my %p = $db->line )
    {
        my $class = $p{class};
        my $net = $p{net};
        my $id = "$class:$net";
        if( ! exists $nets->{$id} )
        {
            $M->fw_net_add($class, $net);
        }
        $M->{nets}{$id} = 1;
        delete $nets->{$id};
    }
    # из фаервола удалим сети, которые были удалены из БД
    foreach my $p( keys %$nets )
    {
        my($class, $net) = split /:/, $p, 2;
        $M->fw_net_del($class, $net);
    }
    $M->Event_run('load_nets', $M->{nets});
}

sub traf_for_period
{
    my($M, $period) = @_;
    my $time_limit = int($M->Time) - $period;
    my @times = @{$M->{traf_time}};
    my $i = 0;
    foreach my $time( @times )
    {
        $time < $time_limit && next;
        return $M->{traf_values}[$i];
    }
     continue
    {
        $i++;
    }
    return {};
}












 
1;