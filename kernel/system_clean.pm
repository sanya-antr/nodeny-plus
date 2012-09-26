#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::system_clean;
use strict;
use Debug;
use Db;
use nod::tasks;
use Time::Local;

our @ISA = qw{kernel};

sub start
{
    my(undef, $single, $param) = @_;

    $param->{single} = $single;

    nod::tasks->new(
        task         => \&main,
        period       => $param->{period} || 24*60*60,
        first_period => $single? 0 : 35,
        param        => $param,
    );
}


sub main
{
    my($task, $param) = @_;
    my $dbh = Db->dbh;
    my $sth = $dbh->prepare('SHOW TABLES');
    if( !$sth->execute )
    {
        debug('error', 'Не выполнен sql: SHOW TABLES');
        return;
    }

    my $Z_time = time() - $param->{traf_Z_day}*24*3600;
    my $X_time = time() - $param->{traf_X_day}*24*3600;

    while( my $p = $sth->fetchrow_arrayref )
    {
        $p->[0] =~ /^(Z|X)(\d\d\d\d)_(\d+)_(\d+)$/ or next;
        my $tbl_type = $1;
        my $time = timelocal(59,59,23,$4,$3-1,$2);
        if( ($tbl_type eq 'Z' && $time < $Z_time) ||
            ($tbl_type eq 'X' && $time < $X_time)
        ){
            Db->do("DROP table $p->[0]");
        }
    }

    $param->{single} or return;
    tolog('end');
    exit;
}

1;