#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head INFO

 Пополнение мобильных телефонов через Liqpay

=cut

use strict;
use nod::liqpay;

sub go
{
    my($Url,$usr) = @_;
    my $amt_min = $cfg::liqpay_phone_amt_min + 0;
    my $amt_max = $cfg::liqpay_phone_amt_max + 0;
    my $commision = $cfg::liqpay_phone_commision + 0;
    
    $amt_min = 1 if $amt_min < 1;
    $amt_max = 10 if $amt_max < 1;
    $commision = 0 if $commision < 0;

    _lang();

    Doc->template('top_block')->{title} = $lang::liqpay_title;

    my($go, $phone, $amt) = ses::input('go', 'phone', 'amt');

    if( ! $go )
    {
        my $sample_amt = int(($amt_min + $amt_max)/2);
        $amt ||= $sample_amt;
        $phone ||= '380';
        my $msg = tmpl( \$lang::liqpay_intro,
            input_phone => v::input_t( name=>'phone', value=>$phone ),
            input_amt   => v::input_t( name=>'amt',   value=>$amt ),
            submit      => v::submit($lang::btn_go_next),
            gr          => $cfg::gr,
            commision   => $commision,
            min_amt     => $amt_min,
            sample_amt  => $sample_amt,
            sample_amt_w_commision => $sample_amt + $commision,
        );

        Show MessageBox( $Url->form( go=>1, $msg ) );
        return 1;
    }

    my $url = $Url->new( phone=>$phone, amt=>$amt );

    $phone =~ s/^\+//;
    $phone =~ s/\s//g;
    if( $phone =~ /\D/ || length($phone) < 7 )
    {
        $url->redirect( -error=>1, -made=>$lang::liqpay_err_phone );
        die;
    }

    $amt += 0;
    if( $amt <= 0 || $amt < $amt_min || $amt > $amt_max )
    {
        $url->redirect( -error=>1, -made=>_($lang::liqpay_err_amt, $amt_min, $amt_max) );
        die;
    }

    my $amt_w_commision = $amt + $commision;

    if( $amt_w_commision > $usr->{balance} )
    {
        $url->redirect( -error=>1, -made=>_($lang::liqpay_err_no_money, $usr->{balance}) );
        die;
    }

    my %p = nod::liqpay::API(
        action      => 'view_balance',
        merchant_id => $cfg::liqpay_merch_id,
    );

    if( $p{error} )
    {
        debug('warn', 'Не удалось получить балансы нашего мерчанта в Liqpay:', $p{error});
        Error($lang::s_soft_error);
    }
    if( ! ref $p{result}->{balances} )
    {
        debug('warn','pre', 'В xml от Liqpay API нет тега balances:', $p{result});
        Error($lang::s_soft_error);
    }
    my $liqpay_balance = $p{result}->{balances}{$cfg::liqpay_currency};
    if( $liqpay_balance < $amt )
    {
        debug('warn','pre', "На $cfg::liqpay_currency счету мерчанта недостаточно денег:", $p{result});
        $Url->redirect( a=>'u_main', -made=>$lang::liqpay_stop );
    }

    # Сначала снимем деньги, потому как нет гарантии, что в Liqpay не будет проблем. Например, Liqpay
    # будет пополнять телефоны, а ответные пакеты доходить не будут, тогда возможно будет расскатать
    # все деньги на счету мерчанта Liqpay. Если же пополнение не состоится - админ удалит платеж вручную.
    # Более того, трудно проверить действительно ли номер существует, поэтому, если клиент будет вводить
    # невалидные номера - он будет какбы штрафоваться, т.е прекратит свои эксперименты быстро.

    my $pay_id;
    my $ok;
    {
        Db->begin_work || last;

        my $reason = Debug->dump({ module=>'liq_phone' });
        my $rows = Pay_to_DB(
            uid     => $usr->{id},
            category=> 100,
            cash    => -$amt_w_commision,
            reason  => $reason,
            comment => "Пополнение телефона $phone на сумму $amt $cfg::gr. Комиссия $commision $cfg::gr",
        );
        $rows < 1 && last; 
        $pay_id = Db::result->insertid || last;
 
        $rows = Db->do(
            "UPDATE users SET balance=balance-(?) WHERE id=? AND balance>? LIMIT 1",
            $amt_w_commision, $usr->{id}, $amt_w_commision,
        );
        $rows < 1 && last;
        $ok = 1;
    }
    if( ! $ok || ! Db->commit )
    {
        Db->rollback;
        Error($lang::s_soft_error);
    } 

    my %p = nod::liqpay::API(
        action      => 'phone_credit',
        merchant_id => $cfg::liqpay_merch_id,
        amount      => $amt,
        currency    => $cfg::liqpay_currency,
        phone       => $phone,
        order_id    => $pay_id,
    );

    # Здесь мы не знаем пополнился ли мобильник или бока с соединением.
    # Можно проверить состояние платежа, однако, ситуация редкая и разрулится админом вручную

    if( $p{error} )
    {
        debug('warn', $p{error});
        $Url->redirect( a=>'u_main', -made=>$lang::liqpay_err_proc );
    }

    debug('pre', $p{result});
    
    if( $p{result}->{status} ne 'success' )
    {
        debug('warn', 'Статус операции не `success`');
        $Url->redirect( a=>'u_main', -made=>$lang::liqpay_err_proc );
    }
    $Url->redirect( a=>'u_main',
        -made => tmpl( \$lang::liqpay_ok_proc,
            amt   => $p{result}->{amount},
            gr    => $cfg::gr,
            phone => $p{result}->{phone},
        )
    );
}

sub _lang
{
 $lang::liqpay_title = 'Пополнение счета мобильного телефона';

 $lang::liqpay_intro = <<MSG;
    <div class='big'>Пополнение счета мобильного телефона</div>
    <hr class='space'>
    <p>Вы можете перечислить на мобильный телефон деньги с вашего баланса в нашей системе.<p>
    <p>Дополнительно будет снята комиссия в размере <b>{{commision}}</b> {{gr}}.</p>
    <p>Например, при пополнении телефона на {{sample_amt}} {{gr}},
    с вашего счета будет снято {{sample_amt_w_commision}} {{gr}}.</p>
    <p>Минимальная сумма пополнения <b>{{min_amt}}</b> {{gr}}.</p>
    <hr class='space'>
    <hr/>

        <div class='align_center'>номер мобильного телефона {{input_phone}}</div><br>
        <div class='align_center'>сумма пополнения {{input_amt}} {{gr}}</div><br>
        <div class='align_center'>{{submit}}</div>
MSG

 $lang::liqpay_err_phone    = 'Телефонный номер задан неверно';
 $lang::liqpay_err_amt      = "Сумма должна быть в пределах [] .. [] $cfg::gr";
 $lang::liqpay_err_no_money = "На вашем счету недостаточно финансов: [] $cfg::gr";
 $lang::liqpay_stop         = 'Сервис пополнения мобильного телефона временно недоступен';
 $lang::liqpay_err_proc     = 'С вашего счета снята сумма и отправлен запрос на пополнение, однако, видимо где-то по пути произошла ошибка. '.
                                'Если в течение часа счет телефона не будет пополнен - обратитесь к администрации.';
 $lang::liqpay_ok_proc      = '{{amt}} {{gr}} отправлено на телефон {{phone}}. Ожидайте в ближайшем времени поступления.';
}

1;
