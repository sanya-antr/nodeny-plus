#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use web::Pay;

sub go
{
 my($url,$usr) = @_;
 my $uid = $usr->{id};
 my $sql = ["SELECT * FROM pays WHERE mid=? AND (cash<>0 OR comment<>'') ORDER BY time DESC", $uid];
 my($sql, $page_buttons, $rows, $db) = Show_navigate_list($sql, ses::input_int('start'), 15, $url);
 $rows>0 or return;
 my $tbl = tbl->new( -class=>'td_tall td_wide' );
 $tbl->add('head', 'rrrrcl', @lang::sPays_tbl_head, '');
 my $i = 0;
 my $balance = 0;
 while( my %p = $db->line )
 {
    my $decode = Pay::decode(\%p);
    my $time = $p{time};
    if( !$i++ )
    {  # Вычислим баланс в текущий момент, вне цикла нельзя из-за страниц навигации
       my %h = Db->line("SELECT SUM(cash) AS money FROM pays WHERE mid=? AND time<=?", $uid, $time);
       %h or return;
       $balance = $h{money};
    }
    my $cash = $p{cash};
    my $money = sprintf("%.2f",$cash)+0;
    $tbl->add('*','rrrrll',
        [ the_short_time($time) ],
        $money>0 && $money,
        $money<0 && -$money,
        $money!=0 && sprintf("%.2f",$balance)+0,
        [ $decode->{for_usr} ],
        [ !!Adm->id && url->a('info', a=>'ajPayInfo', id=>$p{id}, -ajax=>1) ]
    );
    $balance -= $cash;
 }

 Show $page_buttons.$tbl->show.$page_buttons;
}

1;
