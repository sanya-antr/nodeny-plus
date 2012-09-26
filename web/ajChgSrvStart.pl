#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head
    Изменение времени старта услуги, уже подключенной клиенту
    
    uid     : id клиента
    id      : id строки с услугой в таблице users_services
    domid   : dom id элемента, в который выводить результат

=cut

use strict;

my $res = _proc();

$res && push @$ses::cmd, {
    id   => ses::input('domid'),
    data => _('[div small_msg]',$res),
};

sub _proc
{
    Adm->chk_privil_or_die('SuperAdmin');

    my($uid, $id) = ses::input_int('uid','id');
    my $domid = ses::input('domid');

    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my($start_date, $end_date);
    my($day,$mon,$year) = split /\./, ses::input('start_date');
    eval{ $start_date = timelocal(0,0,0,$day,$mon-1,$year) };
    $@ && return 'Дата введена некорректно';
    my($day,$mon,$year) = split /\./, ses::input('end_date');
    eval{ $end_date = timelocal(0,0,0,$day,$mon-1,$year) };
    $@ && return 'Дата введена некорректно';
    
    my $rows = Db->do(
        "UPDATE users_services SET tm_start=?, tm_end=? WHERE uid=? AND id=?",
        $start_date, $end_date, $uid, $id,
    );
    return $rows>0? 'Данные услуги изменены' : $lang::err_try_again;
}

1;