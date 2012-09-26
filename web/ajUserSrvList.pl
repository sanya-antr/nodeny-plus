#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head
    Посылает в DOM-элемент с id = 'mUser_srv_list' список услуг клиента uid
=cut

use strict;
use vars qw( $Ugrp );


push @$ses::cmd, {
    id   => 'mUser_srv_list',
    data => _proc(),
};

return 1;

sub _proc
{
    my $uid = ses::input_int('uid');
    my $info = Get_usr_info($uid) or return $lang::err_try_again;
    $info->{id} or return "User id=$uid не найден в базе";
    Adm->chk_usr_grp($info->{grp}) or return "Нет доступа к группе user id=$uid";

    my $result = _('Баланс [bold] [][br2]', $info->{balance}, $cfg::gr);

    my $db = Db->sql(
        "SELECT v.id, v.title, p.cash FROM v_services v LEFT JOIN pays p ON v.pay_id=p.id ".
        "WHERE v.uid=?", $uid
    );
    $db->ok or return $lang::err_try_again;
    $db->rows or return $result;

    my $tbl = tbl->new( -class=>'td_wide td_medium' );
    $tbl->add('', 'll', 'Услуга', 'Стоимость');
    while( my %p = $db->line )
    {
        my $domid = v::get_uniq_id();
        my $title = url->a($p{title}, -ajax=>1, a=>'ajUserSrvInfo', uid=>$uid, id=>$p{id}, domid=>$domid);
        my $cash = $p{cash}>0? 'Бонус ' : '';
        $cash .= abs($p{cash}).' '.$cfg::gr;
        $tbl->add('', 'll', [ $title ], [ $cash ] );
        $tbl->add('', 'L',  [ _("[div id=$domid]") ] );
    }
    return $result.$tbl->show;
}

1;