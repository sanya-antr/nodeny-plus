#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head1 INFO
 Пополнение счета через Click&Buy (CnB) системы Liqpay

 Если клиент произвел платеж в Liqpay и не вернулся в NoDeny либо же
 выбрал режим оплаты наличными через терминал, то проведет платеж
 скрипт /../cgi-bin/liqpay.pl. В Liqpay это т.н. сервер-сервер пакеты.

 Этап 1: _show_input_amt_form()
    Вывод формы с полем ввода суммы пополнения

 Этап 2: _make_CnB_request()
    Редирект клиента в Liqpay

 Этап 3: _proc_CnB_reply()
    Клиент возвращается с сайта Liqpay и в случае успешного ответа:
        - если платеж наличными, то редирект на _show_pay_result()
        - если платеж картой или деньгами Liqpay, то редирект на титульную страницу

 Структура поля reason таблицы pays (данные разделяются двоеточием):
    плат.система        'liqpay'
    время               timestamp
    amount
    --- эти данные будут созданы после завершения транзакции:
    phone
    transaction_id      id транзакции в Liqpay
    pay_way             способ оплаты (карта/валюта ликпей/наличные)

=cut

use strict;
use nod::liqpay;

# Время существования заявки в платежном терминале
$ses::exp_time = int($cfg::liqpay_exp_time) || 48;
$cfg::liqpay_amt_min ||= 0;
$cfg::liqpay_amt_max ||= 1000;

sub go
{
 my($url,$usr) = @_;
 _lang();

 Doc->template('top_block')->{title} = $lang::liqpay_title;

 $cfg::liqpay_merch_sign or Error(
    Adm->id? 'Liqpay plugin is not configured' : $lang::s_temporarily_unavailable
 );

 ses::input('act') eq 'finish' && return _show_pay_result($url,$usr);
 
 ses::input('act') eq 'step3'  && return _proc_CnB_reply($url,$usr);

 ses::input('act') eq 'step2'  && return _make_CnB_request($url,$usr);

 # Админ может запросить статус платежа в Liqpay, если сервер-сервер ответ не дошел
 ses::input('act') eq 'status' && return _pay_status($url,$usr);

 return _show_input_amt_form($url,$usr);
}


sub _show_input_amt_form
{
 my($url,$usr) = @_;
 # Если есть задолженность, то сумму приведем к ближайшему кратному 5
 my $amt = -$usr->{balance};
 $amt = $amt>=5? int($amt/5 + .999)*5 : '';
 $amt = $cfg::liqpay_amt_max if $amt > $cfg::liqpay_amt_max;
 my $input_amt = v::input_t( name=>'amt', value=>$amt )." $cfg::gr ".v::submit($lang::btn_go_next);
 my $msg = tmpl(\$lang::liqpay_intro, input=>$input_amt );
 Show MessageBox( $url->form(act=>'step2', $msg) );

 # Список заявок за последние 5 суток
 {
    my $uid = $usr->{id};
    my $sql = "SELECT id,time,reason FROM pays WHERE mid=$uid AND category IN(444,445) ".
        "AND reason LIKE 'liqpay:%' AND time>(unix_timestamp()-3600*24*15) ORDER BY time DESC";
    my($sql,$page_buttons,$rows,$db) = Show_navigate_list($sql, ses::input_int('start'), 20, $url);
    $rows < 1 && last;
    my $tbl = tbl->new( -class=>'td_tall td_wide' );
    while( my %p = $db->line )
    {
        my(undef,undef,$amt,$phone) = split /:/,$p{reason};
        $amt = sprintf "%.2f", $amt;
        $tbl->add('*','llllc',
            [ the_short_time($p{time}) ],
            $amt,
            $phone,
            ($ses::t - $p{time}) > $ses::exp_time*60*60 && $lang::smsadm_expired_pay,
            [ !!Adm->id &&
                url->a($lang::smsadm_btn_more, a=>'pays', act=>'show', id=>$p{id}).' '.
                $url->a('Статус', act=>'status', id=>$p{id})
            ],
        );
    }
    $tbl->ins('head', 'lll  ', $lang::lbl_time, $lang::lbl_amt.' '.$cfg::gr, $lang::lbl_phone, '', '');
    $tbl->ins('head', 4, $page_buttons) if $page_buttons;
    $tbl->add('head', 4, $page_buttons) if $page_buttons;
    Show MessageWideBox( _('[p big]',$lang::liqpay_waiting_pays).$tbl->show );
 }
 return;
}


# --- формирование заявки ---

sub _make_CnB_request
{
 my($url,$usr) = @_;
 if( $cfg::liqpay_pays_per_day>0 )
 {
    my %p = Db->line(
        "SELECT COUNT(*) AS n FROM pays WHERE mid=? AND category IN(444,445,446) ".
            "AND time>(unix_timestamp()-3600*24) AND reason LIKE 'liqpay:%'", $usr->{id}
    );
    %p && $p{n}>$cfg::liqpay_pays_per_day && 
        Error("Количество заявок на пополнение счета превысило допустимое ($cfg::liqpay_pays_per_day в сутки). ".
            "Повторите запрос позже");
 }

 my $amt = ses::input('amt') + 0;
 $amt>0 or return _show_input_amt_form($url,$usr);

 if( $amt < $cfg::liqpay_amt_min || $amt > $cfg::liqpay_amt_max )
 {
    ErrorMess("Указанная вами сумма недопустима, укажите в пределах $cfg::liqpay_amt_min .. $cfg::liqpay_amt_max $cfg::gr");
    return _show_input_amt_form($url,$usr);
 }

 Pay_to_DB(uid=>$usr->{id}, category=>444, reason=>'liqpay'.':'.$ses::t.':'.$amt) < 1 && Error($lang::s_soft_error);
 my $pay_id = Db::result->insertid || Error($lang::s_soft_error);

 my %p = nod::liqpay::CnB(
    merchant_id => $cfg::liqpay_merch_id,
    server_url  => $cfg::liqpay_return_url,
    result_url  => $ses::script_url.$url->url( act=>'step3' ),
    amount      => $amt,
    currency    => $cfg::liqpay_currency,
    order_id    => $pay_id,
    description => $cfg::liqpay_description.' '.Make_PPC($usr->{id}),
    exp_time    => $ses::exp_time,
    pay_way     => 'delayed,card,liqpay',
 );

 $p{error} && Error( Adm->id? $p{error} : $lang::s_soft_error );

 url->redirect( -base=>$cfg::liqpay_cnb_url, operation_xml=>$p{operation_xml}, signature=>$p{signature});
}


# --- Ответ от сервера Liqpay ---

sub _proc_CnB_reply
{
    my($url,$usr) = @_;
    my %p = nod::liqpay::CnB_reply(
        operation_xml => ses::input('operation_xml'),
        signature     => ses::input('signature'),
    );

    $p{error} && Error( Adm->id? $p{error} : $lang::s_soft_error );

    my $data = $p{result};

    my $status  = $data->{status};
    my $pay_id  = $data->{order_id};

    if( $status eq 'delayed' || $status eq 'wait_secure' )
    {
        # Оплата наличными через терминал либо платеж на проверке
        # Ставим категорию: `заявка принята платежной системой`
        Db->do(
            "UPDATE pays SET time=unix_timestamp(), category=445,".
                " reason=CONCAT(reason,':',?,':',?,':',?) ".
            "WHERE category=444 AND id=? LIMIT 1",
                $data->{sender_phone}, $data->{transaction_id}, $data->{pay_way}, $pay_id
        );
    
    }
     elsif( $status eq 'success' )
    {
        _pay_success($data) or Error($lang::liqpay_internal_error);
    }
     else
    {
        debug("status: `$status`. Считаем транзакцию неуспешной");
    }

    $url->redirect( act=>'finish', status=>$status, amt=>$data->{amount} );
}

sub _show_pay_result
{
    my($url,$usr) = @_;
    my $msg;
    if( ses::input('status') eq 'delayed' )
    {
        $msg = tmpl( \$lang::liqpay_delayed_ok, amt=>v::filtr(ses::input('amt')) );
    }
     elsif( ses::input('status') eq 'success' )
    {
        $msg = $lang::liqpay_result_ok;
    }
     elsif( ses::input('status') eq 'wait_secure' )
    {
        $msg = $lang::liqpay_result_wait;
    }
     else
    {
        $msg = $lang::liqpay_result_fail;
    }
    Show MessageBox( $msg );
}


sub _pay_status
{
    my($url,$usr) = @_;
    Adm->id or Error(':)');
    my $pay_id = ses::input_int('id') or return Error('pay id required');

    Show MessageBox( $lang::liqpay_pay_status_chk );

    my %p = nod::liqpay::API(
        action => 'view_transaction',
        merchant_id => $cfg::liqpay_merch_id,
        transaction_order_id => $pay_id,
    );

    # Раздел доступен только админу, поэтому можно выводить детализацию ошибки
    $p{error} && Error( $p{error} );

    debug('pre', $p{result});

    my $data = $p{result}->{transaction};

    $data->{order_id} == $pay_id or Error('Несоответствие данных: несовпадение order_id');
    if( $data->{status} ne 'success' )
    {
        Show MessageBox('Транзакция (пока еще) неуспешна. Статус транзакции: '.$data->{status});
        return 1;
    }

    _pay_success($data);

    $url->redirect( a=>'u_main', -made=>'Платеж успешен' );
}

sub _pay_success
{
    my($data) = @_;

    Db->begin_work or return 0;

    my $rows1 = Db->do(
        "UPDATE pays SET category=20, time=unix_timestamp(), ".
            "cash=?, reason=CONCAT(reason,':',?,':',?,':',?) ".
        "WHERE category IN(444,445) AND id=? LIMIT 1",
            $data->{amount}, $data->{sender_phone}.'', $data->{transaction_id}.'', $data->{pay_way}, $data->{order_id}
    );
    my $rows2 = Db->do(
        "UPDATE users SET state = IF(balance+(?) >= limit_balance, 'on', state), balance=balance+(?) ".
        "WHERE id = (SELECT mid FROM pays WHERE id=? LIMIT 1) LIMIT 1",
            $data->{amount}, $data->{amount}, $data->{order_id}
    );

    if( $rows1 < 1 || $rows2 < 1 || !Db->commit )
    {
        Db->rollback;
        return 0;
    }
    return 1;
}

sub _lang
{
 $lang::liqpay_title = 'Пополнение счета через систему Liqpay';

 $lang::liqpay_intro = <<MSG;
    <div class='big'>Пополнение счета через платежные терминалы Приватбанка либо карту Visa/Mastercard:</div>
    <hr class='space'>
    <ul>
        <li>На данной странице укажите сумму, на которую хотите пополнить счет;</li>
        <li>Наша система направит вас на сайт системы Liqpay Приватбанка;</li>
        <li>Подтвердите оплату, введя номер своего телефона. На ваш телефон придет смс с кодом.
            Этим самым система удостоверится, что вы являетесь владельцем телефона, а не кто-то иной ввел ваш номер;</li>
        <li>Выбирете способ оплаты: наличными или пластиковой картой;</li>
        <li>Если вы выбирете способ опаты "наличными", вам необходимо подойти к любому платежному терминалу Приватбанка и
            выполнить инструкции, которые выдаст система Liqpay.</li>
    </ul>
    <hr class='space'>
    <hr/>
    <hr class='space'>
    <div class='align_center'>
        <div class='txtpadding'>Введите сумму пополнения в пределах $cfg::liqpay_amt_min .. $cfg::liqpay_amt_max $cfg::gr:</div>
    </div>
    <div class='align_center'>
        <div class='txtpadding'>{{input}}</div>
    </div>
MSG

 $lang::liqpay_delayed_ok = <<MSG;
    <div class='big'>Первый шаг процедуры оплаты выполнен!</div>
    <hr class='space'>
    <div class='big'>Теперь необходимо внести {{amt}} $cfg::gr в любой платежный терминал Приватбанка,
    указав номер вашего мобильного телефона.</div>
    <hr/>
    <hr class='space'>
    <img src='$cfg::img_dir/1step_cash.png'>
    <img src='$cfg::img_dir/2step_cash.png'>
    <img src='$cfg::img_dir/3step_cash.png'>
    <hr class='space'>
MSG

 $lang::liqpay_pay_status_chk = <<MSG;
    Проверка статуса платежа. Операция необходима, когда есть подозрение, что платеж успешен в системе Liqpay, но
    в текущей системе заявка за пополнение не отмечена как уцспешная.
    Если платеж успешен и завершен, то заявка будет помечена как успешная, клиенту будут начислены деньги и
    обновлен баланс. Операция безопасная, т.е. повторно деньги не могут быть начислены.
MSG

 $lang::liqpay_waiting_pays         = 'Ваши заявки, которые ожидают оплату в терминале';
 $lang::smsadm_expired_pay          = 'Срок заявки скорее всего истек (определяется терминалом Приватбанка)';
 $lang::liqpay_internal_error       = 'Произошла небольшая ошибка, обратитесь к администрации';
 $lang::liqpay_result_ok            = "<p class='big'>Оплата осуществлена</p>";
 $lang::liqpay_result_fail          = 'Оплата в системе Liqpay не прошла';
 $lang::liqpay_result_wait          = "<p class='big'>Платеж на проверке в системе Liqpay</p>".
                                        "<p class='big'>Деньги будут зачислены сразу после завершения проверки</p>";
}

1;
