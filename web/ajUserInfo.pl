#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

if( !$ses::ajax )
{
    Require_web_mod('user');
    return 1;
}

push @$ses::cmd, {
    id   => 'modal_window',
    data => _proc(),
};

return 1;

sub _proc
{
    my $uid = ses::input_int('uid');
    my $info = Get_usr_info($uid) or return $lang::err_try_again;
    $info->{id} or return "User id=$uid не найден в базе";
    Adm->chk_usr_grp($info->{grp}) or return "Нет доступа к группе user id=$uid";
    return $info->{full_info};
}

1;
