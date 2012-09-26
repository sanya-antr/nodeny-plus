#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head
    Вывод информации по услуге

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

return 1;

sub _proc
{
    my($uid, $id) = ses::input_int('uid','id');
    my $domid = ses::input('domid');

    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my %p = Db->line(
        "SELECT v.*, s.title AS next_title, p.cash FROM v_services v LEFT JOIN services s ON v.next_service_id = s.service_id ".
            "LEFT JOIN pays p ON v.pay_id = p.id ".
            "WHERE v.uid = ? AND v.id = ?",
        $uid, $id
    );
    Db->ok or return $lang::err_try_again;
    %p or return 'Информация по услуге не получена. Возможно уже завершилась';

    my $url = url->new( a=>ses::cur_module, -ajax=>1, uid=>$uid, id=>$id, domid=>$domid );

    my $tbl = tbl->new(-class=>'td_wide td_medium', -row1=>'row3', -row2=>'row3');
    #$tbl->add('*', 'll', 'Услуга', $p{title});

    if( $p{pay_id} && !defined $p{cash} )
    {
       $tbl->add('*', 'L', 'Платеж, связанный с услугой, не существует!');
    }

    $tbl->add('*', 'll', 'Описание', $p{description});
    $tbl->add('*', 'll', 'Старт', [ the_short_time($p{tm_start}) ]);
    if( $p{tm_end} )
    {
        $tbl->add('*', 'll', 'Конец', [ the_short_time($p{tm_end}) ]);
        $p{tm_end}<$ses::t && $tbl->add('*', 'L', 'Будет завершена с минуты на минуту');
    }
     else
    {
        $tbl->add('*', 'L', 'Не имеет срока действия');
    }
    $tbl->add('*', 'll', 'Следующая услуга', $p{next_service_id}? $p{next_title} : $lang::no);

    my @urls = ();
    if( Adm->chk_privil('Admin') )
    {
        push @urls, url->a('Детальнее', a=>'op', act=>'services', op=>'edit', id=>$p{service_id});
    }
    if( Adm->chk_privil(90) )
    {
        push @urls, $url->a('Автопродление', a=>'ajUserSrvAdd', cmd=>'set_next', cur_service_id=>$p{service_id});
        if( ses::input('del') )
        {
            push @urls, $url->a('Завершить услугу?', a=>'ajUserSrvDel', -class=>'error');
            push @urls, _('[div txtpadding]', 'При завершении услуги, уменьшится стоимость услуги пропорционально использованному времени');
        }
         else
        {
            push @urls, $url->a('Завершить', del=>1);
        }
    }
    if( Adm->chk_privil('SuperAdmin') )
    {
        push @urls, $url->a('Изменить', a=>'ajUserSrvForm');
    }

    $tbl->add('navmenu', 'L', [ join('',@urls) ]);

    return $tbl->show;
}

1;