#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::auth;
use strict;
use Time::localtime;
use Debug;
use Db;
use nod::tasks;

our @ISA = qw{kernel};

sub start
{
    my(undef, $single, $param) = @_;

    nod::tasks->new(
        task         => \&main,
        period       => $param->{period} || 5,
        first_period => $single? 0 : 2,
        param        => $param,
    );
}

sub main
{
    my($task, $param) = @_;
    $param->{timeout} ||= 150;
    # Удаляем записи из будущего не чаще раз в 10 минут
    nod::tasks->protect_time(600, 'auth_wrong_time') && 
        Db->do("DELETE FROM auth_now WHERE last>(UNIX_TIMESTAMP()+60)");

    my @sql_param = ();
    my $i = 0;
    my $db = Db->sql("SELECT * FROM v_ips WHERE last<(UNIX_TIMESTAMP()-?)", $param->{timeout});
    while( my %p = $db->line )
    {
        my $rows = Db->do("DELETE FROM auth_now WHERE ip=? AND last<(UNIX_TIMESTAMP()-?)", $p{ip}, $param->{timeout});
        $rows>0 or next;
        $i++;
        push @sql_param, $p{uid}, $p{ipn}, $p{start}, $p{last}, $p{properties};
    }
    if( $i )
    {
        my $sql = "INSERT INTO auth_log (uid,ip,start,end,properties) VALUES";
        $sql .= join ',', map{'(?,?,?,?,?)'}(1..$i);
        Db->do($sql, @sql_param);
    }

    # Освобождение динамических ip
    Db->do("UPDATE ip_pool set uid=0 WHERE type='dynamic' AND uid>0 AND `release`<UNIX_TIMESTAMP()");
}

1;