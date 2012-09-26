#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::chk_traf;
use strict;
use Debug;
use Db;
use services;
use nod::tasks;

our @ISA = qw{kernel};

sub start
{
    my(undef, $single, $param) = @_;

    nod::tasks->new(
        task         => \&main,
        period       => 10,
        first_period => 2,
    );
}

sub main
{
    my $db = Db->sql(
        'SELECT t.uid FROM users_trf t JOIN users_limit l ON t.uid=l.uid WHERE ('.
            '(l.traf1>0 AND (t.in1+t.out1)>l.traf1) OR '.
            '(l.traf2>0 AND (t.in2+t.out2)>l.traf2) OR '.
            '(l.traf3>0 AND (t.in3+t.out3)>l.traf3) OR '.
            '(l.traf4>0 AND (t.in4+t.out4)>l.traf4) '.
        ") AND EXISTS(SELECT uid FROM v_services s WHERE s.tags LIKE '%,trafic_limit,%' AND s.uid=t.uid)"
    );
    while( my %p = $db->line )
    {
        my $id = $p{uid};
    }
}

1;