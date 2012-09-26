#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::lost_ping;
use strict;
use Debug;
use Db;
use nod::tasks;
use threads;
use threads::shared;

our @ISA = qw{kernel};

my %Ips : shared;
my $step : shared;

my $v;

my $Period;
my $Data_field;
my $Ping_cmd;
my $Regexp;

sub start
{
    my(undef, $single, $param) = @_;

    $v = $cfg::verbose;

    $Period     = $param->{period} || 5*60;
    $Data_field = $param->{data_field} || 'lost_ping';
    $Ping_cmd   = $param->{ping_cmd} || '/sbin/ping -fqn -c 100';
    $Regexp     = $param->{regexp} || '(\d+\.\d+)% packet loss';

    nod::tasks->new(
        task         => \&main,
        period       => 2,
        first_period => $single? 0 : 20,
    );

    threads->create( \&main_thread ) or die 'cannot create thread';
}

sub main_thread
{
    $SIG{'INT'} = sub { threads->exit() };

    MAIN: while( 1 )
    {
        {
            lock $step;
            $step eq 'start' or next MAIN;
            $step = 'ping';
        }
        foreach my $ip( keys %Ips )
        {
            my $cmd = "$Ping_cmd $ip  2>/dev/null";
            # Возможно, Debug не потокобезопасный, поэтому тока в verbose mode вызываем debug()
            $v && debug("запускаем: $cmd");
            my $res = `$cmd`;
            $v && debug("Регуляркой /$Regexp/ проверяем результат:\n$res");
            if( $res !~ /$Regexp/ || $1 == 100 )
            {
                $v && $1 == 100 && debug('100% потери не регистрируем');
                delete $Ips{$ip};
                next;
            }
            my $loss = $1;
            $v && debug("Потери: $loss %");
            # Если 0% потерь, то примем их мизерными, чтобы было отличие от тех ip, которые не пингуются
            $loss = '0.001' if $loss == 0;
            $Ips{$ip} .= ' '.$loss;
        }
        lock $step;
        $step = 'process';
    }
     continue
    {
        sleep 1;
    }
}

sub main
{
    my($task) = @_;
    lock $step;
    if( $step eq 'ping' )
    {
        $task->{period} = 2;
        return;
    }
    if( $step eq 'process' )
    {
        foreach my $ip( keys %Ips )
        {
            my($uid, $loss) = split / +/, $Ips{$ip}, 2;
            defined $loss or next;
            Db->do("UPDATE data0 SET $Data_field=? WHERE uid=?", $loss, $uid);
        }
    }
    $step = '';
    %Ips  = ();
    my $db = Db->sql("SELECT id,ip FROM v_auth_now");
    while( my %p = $db->line )
    {
        $Ips{$p{ip}} = $p{id};
    }
    $step = 'start';
    $task->{period} = $Period;
}


1;