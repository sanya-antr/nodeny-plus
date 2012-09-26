#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::websession;
use strict;
use Debug;
use Db;
use nod::tasks;

our @ISA = qw{kernel};

sub start
{
    my(undef, $single, $param) = @_;;

    nod::tasks->new(
        task         => \&main,
        period       => $param->{period} || 60,
        first_period => $single? 0 : 11,
    );
}

sub main
{
    Db->do("DELETE FROM websessions WHERE expire < UNIX_TIMESTAMP()");
    Db->do("DELETE FROM webses_data WHERE expire < UNIX_TIMESTAMP()");
}

1;