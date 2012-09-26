#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

my $res = _proc();

$res && push @$ses::cmd, {
    id   => ses::input('domid'),
    data => _proc(),
};

return 1;

sub _proc
{
    Adm->chk_privil_or_die('edt_usr');
    Adm->chk_privil_or_die(81);

    my $uid = ses::input_int('uid');
    my $ipn = ses::input_int('ipn');

    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my $rows = Db->do("UPDATE ip_pool SET uid=0 WHERE uid=? AND ip=? LIMIT 1", $uid, $ipn);
    if( $rows>0 )
    {
        Db->do("DELETE FROM auth_now WHERE ip=INET_NTOA(?) LIMIT 1", $ipn);
    }

    $rows<1 && return _('[span error]', 'Ip не удален');

    Require_web_mod('ajUserIpList');
    return '';
}

1;