#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head
    uid     : id клиента
    id      : id строки с услугой в таблице users_services
    domid   : dom id элемента, в который выводить результат

=cut

use strict;

my $res = _proc();

# unshift чтобы js выполнился позже
$res && unshift @$ses::cmd, {
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

    my %p = Db->line(
        "SELECT DATE_FORMAT(FROM_UNIXTIME(tm_start),'%d.%m.%Y') AS start_date, ".
            "DATE_FORMAT(FROM_UNIXTIME(tm_end),'%d.%m.%Y') AS end_date ".
        "FROM users_services WHERE uid=? AND id=?",
        $uid, $id
    );

    my $tbl = tbl->new( -class=>'td_wide td_tall', -row1=>'row3', -row2=>'row3' );
    $tbl->add('', 'll', 'Cтарт ', [ v::input_t(name=>'start_date', value=>$p{start_date}, size=>8) ]);
    $tbl->add('', 'll', 'Конец ', [ v::input_t(name=>'end_date',   value=>$p{end_date},   size=>8) ]);
    $tbl->add('', 'C', [ v::submit('Изменить') ]);

    my $date_domid = v::get_uniq_id();
    my $form = url->form(
        a=>'ajUserSrvChange', uid=>$uid, id=>$id, domid=>$domid,
        -class=>'ajax', -id=>$date_domid,
        $tbl->show,
    );
    push @$ses::cmd, {
        type => 'js',
        data => "\$('#$date_domid  input[type=text]').simpleDatepicker()",
    };

    return $form;
}

1;