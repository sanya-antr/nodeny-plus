#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package nod::util;
use strict;

=head

    ---- Find_ranges : Поиск диапазонов в массиве с дырками ---

    В числовой последовательности:
        x, x+1, x+2, x+10, x+11, x+12, x+40
    Находим неразрывные диапазоны:
        x    : x+2
        x+10 : x+12
        x+40 : x+40

    Кроме того, учитывается, что числовая последовательность связана с данными, которые
    передаются в ввиде хеша.

        Папример, имеем список карт (id - номер, val - код активации) :

    my $m = [ 
        {id=>10, val=>'aaa'}, {id=>11, val=>'bbb'}, ... {id=>17, val=>'ccc'},
        {id=>20, val=>'ddd'}, {id=>21, val=>'eee'}, ... {id=>25, val=>'fff'},
    ];
    my $ranges = Find_ranges($m, 'id');

        Получим:

    $ranges = [
        [ {id=>10, val=>'aaa'}, {id=>17, val=>'ccc'} ],
        [ {id=>20, val=>'ddd'}, {id=>25, val=>'fff'} ],
    ];
=cut

sub find_ranges
{
    my($m, $key) = @_;
    my $last;
    my $first; # !! не = {};
    my $count = 0;
    my $res = [];
    my $rows = scalar @$m;
    foreach my $current( @$m )
    {
        $count or next;
        ($current->{$key} - $last->{$key}) == 1 && next;
        push @$res, [ $first, $last ];
        $count = 0;
        undef $first;
    } 
     continue
    {
        $first ||= $current;
        $last = $current;
        $count++;
        --$rows or redo;
    }
    return $res;
}


1;
