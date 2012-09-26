#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

return ajModal_window( _proc() );

sub _proc
{
    Adm->chk_privil_or_die(61);
    
    my $uid = ses::input_int('uid');

    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my %p = Db->line("SELECT AES_DECRYPT(passwd,?) AS pass FROM users WHERE id=?", $cfg::Passwd_Key, $uid);
    %p or return $lang::err_try_again;

    my $from = $lang::keyboard_convert{from};
    my $to   = $lang::keyboard_convert{to};

    my $pass = $p{pass};

    utf8::decode($pass);
    utf8::decode($from);
    utf8::decode($to);

    my %tr = map{ substr($from,$_,1) => substr($to,$_,1) } ( 0..length($from)-1 );

    my $res = '';
    foreach( split //, $pass )
    {
        $res .= $tr{$_} || $_;
    }
    utf8::encode($res);
    my $tbl = tbl->new(-class=>'td_wide td_medium');
    $tbl->add('', 'll', 'Пароль', [ v::input_t(value=>$p{pass}) ]);
    $res ne $p{pass} && $tbl->add('', 'll', 'В кириллице',  [ v::input_t(value=>$res) ]);
    return $tbl->show;
}
