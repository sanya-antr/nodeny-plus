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
    Adm->chk_privil('SuperAdmin') or return '';
    my $db_table = $cfg::turbosms_db_login;
    ( !$cfg::turbosms_db_pass || $db_table =~ /[`"'\\]/ ) && return 'Плагин TurboSms не сконфигурирован';

    ses::input('go') or return _('[div small_msg]',
        $Url->form( go=>1, a=>ses::cur_module, domid=>ses::input('domid'), -class=>'ajax', [
            { type=>'text', name=>'phone', value=>'+38', title=>'телефон' },
            { type=>'text', name=>'message', value=>'', title=>'сообщение' },
            { type=>'submit', value=>'sms' },
        ])
    );

    my $sms_db = Db->new(
        host    => $cfg::turbosms_db_server,
        user    => $cfg::turbosms_db_login,
        pass    => $cfg::turbosms_db_pass,
        db      => $cfg::turbosms_db_database,
        timeout => 3,
        tries   => 2,
        global  => 0,
    );

    $sms_db->connect;
    $sms_db->is_connected or return 'Нет соединения с БД TurboSms';

    my $phone = ses::input('phone');
    $phone =~ s/[^\d\+]//g;

    my $rows = $sms_db->do(
        "INSERT INTO $db_table SET number=?, sign=?, message=?, send_time=NOW()",
        $phone, $cfg::turbosms_sign, ses::input('message'),
    );
    return $rows>0? 'Sms поставлена в очередь' : 'Ошибка записи в БД TurboSms';
}
