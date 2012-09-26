#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

push @$ses::cmd, {
    id   => ses::input('domid'),
    data => _proc(),
};

return 1;

sub _proc
{
    my $uid = ses::input_int('uid');

    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my $out;

    {   # --- Последнее обновление авторизации ---
        my %p = Db->line(
            "SELECT MAX(last) AS max_last FROM v_ips WHERE uid=? AND auth>0",
            $uid
        );
        %p or last;
        $p{max_last} or last;
        my $time = $ses::t - $p{max_last};
        $time>0 or last;
        $out .= _('[li]', _('Последнее обновление авторизации [] назад', the_hh_mm_ss($time)) );
    }

    {   # --- Последний срез с входящим и исходящим трафиком ---
        # Имя таблицы текущего дня
        my %p = Db->line("SELECT DATE_FORMAT(NOW(), 'X%Y_%c_%e') AS t");
        %p or last;
        %p = Db->line("SELECT time FROM $p{t} WHERE uid=? AND `in`>0 AND `out`>0 ORDER BY time DESC", $uid);
        Db->ok or last;
        my $msg;
        if( %p )
        {
            $msg = _('Последний двунаправленный трафик [] назад', the_hh_mm_ss($ses::t - $p{time}));
        }
         else
        {
            $msg = 'За текущий день нет двунаправленного трафика у клиента';
        }
        $out .= _('[li]', $msg);
    }

    {   # Последний платеж кроме бонуса и временного платежа
        my %p = Db->line(
            "SELECT cash,time FROM pays WHERE mid=? AND cash>0 AND category NOT IN(2,3) ORDER BY time DESC LIMIT 1",
            $uid
        );
        %p or last;
        my $time = $ses::t - $p{time};
        $time < 0 && last;
        $out .= _('[li]', _('Последний платеж [] [] [] назад', $p{cash}, $cfg::gr, the_hh_mm($time)));
    }

    $out &&= _('[ul]', $out);
    return $out;
}
