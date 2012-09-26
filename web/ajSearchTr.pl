#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;


my $str  = ses::input('str');
my $from = $lang::keyboard_convert{from};
my $to   = $lang::keyboard_convert{to};

utf8::decode($str);
utf8::decode($from);
utf8::decode($to);

my %tr = map{ substr($from,$_,1) => substr($to,$_,1) } ( 0..length($from)-1 );

my $res = '';
foreach( split //, $str )
{
    $res .= $tr{$_} || $_;
}

unshift @$ses::cmd, {
    type   => 'js',
    data   => "\$('#adm_top_search input').trigger('keyup')",
};

unshift @$ses::cmd, {
    id     => 'adm_top_search input',
    action => 'value',
    data   => $res,
};

1;
