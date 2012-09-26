#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
    return ajModal_window( _proc() );
}

sub _proc
{
    my $uid = ses::input_int('uid');
    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my $pay_id = ses::input_int('pay_id');
    my $comment = v::trim( ses::input('comment') );

    my $links = '<hr>';

    $links .= ' '.url->a('Платежи клиента', a=>'pay_log', uid=>$uid, -class=>'nav') if Adm->chk_privil('pay_show');
    $links .= ' '.url->a('Данные клиента', a=>'user', uid=>$uid, -class=>'nav');
    
    !Adm->chk_privil('SuperAdmin') && $comment =~ /[<>]/ && return 'Теги разрешены только суперадмину'.$links;
    $comment =~ s/\n/<br>/g;

    my $rows = Db->do(
        "UPDATE pays SET comment=? ".
            "WHERE id=? AND creator='admin' AND creator_id=? AND category IN(1,2,3,480) AND time>(UNIX_TIMESTAMP()-305)",
        $comment, $pay_id, Adm->id,
    );

    my $out = $rows>0? 'Комментарий установлен' : 
        'Комментарий не установлен - вероятно, со времени создания прошло больше 5 минут';
    $out .= $links;
    return $out;
}

1;