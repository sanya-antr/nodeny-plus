#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
 my($url,$usr) = @_;
 Doc->template('top_block')->{title} .= '. '.$lang::sAuth_log_totop;
 my $sql = [ "SELECT *,INET_NTOA(ip) AS ipa FROM auth_log WHERE uid=? ORDER BY end DESC", $usr->{id} ];
 my($sql, $page_buttons, $rows, $db) = Show_navigate_list($sql, ses::input_int('start'), 20, $url);
 if( !$rows )
 {
    Show MessageBox('Нет данных');
    return 1;
 }
 my $tbl = tbl->new( -class=>'td_tall td_wide' );
 $tbl->add('head', 'llrcl', @lang::sAuth_tbl_head, '');
 while( my %p = $db->line )
 {
    $tbl->add('*', 'llrll',
        [ the_time($p{start},$ses::t) ],
        [ the_time($p{end},$ses::t) ],
        [ the_hh_mm($p{end} - $p{start}) ],
        $p{ipa},
        !!Adm->id && $p{properties},
    );
 }

 Show $page_buttons.$tbl->show.$page_buttons;
}

1;
