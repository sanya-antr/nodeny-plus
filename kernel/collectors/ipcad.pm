#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::collectors::ipcad;
use strict;

sub new
{
    my $collector = shift;
    $SIG{'INT'} = sub { threads->exit() };

    my $rsh = $collector->{rsh};
    my $res;
    my $cmd1 = "$rsh -t 5 -n $collector->{addr} 'cle ip acco' 2>/dev/null";
    my $cmd2 = "$rsh -t 20 -n $collector->{addr} 'sh ip acco che' 2>/dev/null";

    while( 1 )
    {
        while( $collector->{step} != 1 )
        {
            select(undef,undef,undef,0.1)
        }

        {
            $res = `$cmd1`;
            $res = `$cmd1` if ! $res;
            $res or last;
            $res = `$cmd2`;
            $res = `$cmd2` if ! $res;
        }
        $collector->{result} = $res;
        $collector->{step} = 2;
    }
}



1;