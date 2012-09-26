#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

my %types = (
    cash  => { priv => 'pay_cash',  category => 1 },
    bonus => { priv => 'pay_bonus', category => 2 },
    tmp   => { priv => 'pay_tmp',   category => 3 },
    msg   => { priv => 'msg_create',category => 480 },
);

sub go
{
    return ajModal_window( _proc() );
}

sub _proc
{
    my $uid = ses::input_int('uid');
    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my $pay_type = ses::input('type');

    my $pay = $types{$pay_type} or return _('Неизвестный тип платежа [filtr|commas]',$pay_type);

    Adm->chk_privil($pay->{priv}) or return _('У вас нет привилегии [filtr|commas]',$pay->{priv});

    my $amt = ses::input('amt') + 0;
    my $comment = '';
    my $reason = '';
    my $time = $ses::t;

    my @success_msg;
    if( $pay_type eq 'msg' )
    {
        @success_msg = ( 'Сообщение создано.', 'В течение 5 минут можно его изменить:' );
    }
     else
    {
        $amt == 0 && return 'Нельзя пополнить счет на нулевую сумму';
        @success_msg = ( 'Платеж проведен.', 'В течение 5 минут можно установить комментарий, который будет видеть клиент:' );
    }

    $comment = ses::input('msg');
    !Adm->chk_privil('SuperAdmin') && $comment =~ /[<>]/ && return 'Теги разрешены только суперадмину';

    if( $pay_type eq 'tmp' )
    {
        $reason = $ses::t;
        my($day,$mon,$year) = split /\./, ses::input('date');
        eval{ $time = timelocal(0,0,0,$day,$mon-1,$year) };
        $@ && return 'Дата удаления временного платежа введена некорректно';
        $time < $ses::t && return 'Дата удаления временного платежа должна указывать в будущее';
    }

    my($ok, $pay_id);
    {
        Db->begin_work or last;

        Pay_to_DB(
            uid=>$uid, cash=>$amt, time=>$time, category=>$pay->{category}, reason=>$reason, comment=>$comment,
        ) < 1 && last;

        $pay_id = Db::result->insertid;
        $pay_id>0 or last;

        Db->do(
            "UPDATE users SET state=IF(balance+(?) >= limit_balance, 'on', state), balance=balance+(?) WHERE id=?",
            $amt, $amt, $uid,
        ) < 1 && last;

        $ok = 1;
    }

    if( !$ok || !Db->commit )
    {
        Db->rollback;
        return $lang::err_try_again;
    }

    my $links = '';
    $links .= ' '.url->a('Платежи клиента', a=>'pay_log', uid=>$uid, -class=>'nav') if Adm->chk_privil('pay_show');
    $links .= ' '.url->a('Данные клиента', a=>'user', uid=>$uid, -class=>'nav');
    $links .= ' '.url->a('Закрыть', a=>'ajModalClose', -ajax=>1, -class=>'nav');

    {   # Предложим установить комментарий такой же как в предыдущем платеже текущего админа
        $comment && last;
        my %p = Db->line(
            "SELECT comment FROM pays WHERE creator='admin' AND creator_id=? AND category=? AND id<>? ORDER BY time DESC LIMIT 1",
            Adm->id, $pay->{category}, $pay_id,
        );
        %p or last;
        $comment = $p{comment};
    }

    return url->form(
        a=>'ajPayComment', uid=>$uid, pay_id=>$pay_id, -class=>'ajax',
        _('[p bold][p][p h_center][p h_center]<hr><br>[div h_center]',
            @success_msg,
            v::input_ta('comment', $comment, 55, 4),
            v::submit('Выполнить'),
            $links,
        )
    );
}

1;