#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use services;

return ajModal_window( _proc() );

sub _proc
{
    Adm->chk_privil_or_die(90);

    my $uid = ses::input_int('uid');
    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my $actions = {};

    my $err = { for_adm => $lang::err_try_again };
    {
        my %p = Db->line("SELECT pay_id FROM v_services WHERE id=? AND uid=? LIMIT 1", ses::input_int('id'), $uid);
        %p or last;

        $err = services->proc(
            actions => $actions,
            cmd     => 'end',
            id      => ses::input_int('id'),
            uid     => $uid,
        );

        $err or ToLog( Adm->admin, "дострочно завершил услугу id=$p{pay_id} клиента id=$uid" );
    }

    Require_web_mod('ajUserSrvList');

    return $err? $err->{for_adm} : '';
}

1;