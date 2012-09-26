#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::services;
use strict;
use Debug;
use Db;
use nod::tasks;
use services;
use Time::localtime;

our @ISA = qw{kernel};

my $Errors = {};

sub start
{
    my(undef, $single, $param) = @_;

    nod::tasks->new(
        task         => \&main,
        period       => 5,
        first_period => $single? 0 : 6,
    );
}

sub main
{
    my $time = kernel->Time;
    my $db = Db->sql("SELECT * FROM v_services WHERE tm_end > 0 AND tm_end < UNIX_TIMESTAMP()");
    while( my %p = $db->line )
    {
        my $id = $p{id};
        $Errors->{$id} > $time && next;
        my $err = services->proc(
            cmd     => 'next',
            id      => $id,
            uid     => $p{uid},
            creator => {
                type => 'kernel',
                id   => 1,
            },
        );
        if( $err )
        {
            $Errors->{$id} = $time + 120;
            next;
        }
        tolog("Завершена услуга `$p{title}`(id=$id) клиента id=$p{uid}");
    }
}

1;