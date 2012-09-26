#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head INFO

 Перевод средств между счетами клиентов

=cut

use strict;

sub go
{
    my($url,$usr) = @_;
    my $fixed_commision = $cfg::remitter_f_commision + 0;   # фиксированная комиссия
    my $var_commision = $cfg::remitter_v_commision + 0;     # процентная комиссия
    my $amt_min = $cfg::remitter_amt_min + 0;
    my $amt_max = $cfg::remitter_amt_max + 0;
    $fixed_commision = 0 if $fixed_commision < 0;
    $var_commision = 0 if $var_commision < 0;
    $amt_min = 1 if $amt_min < 1;
    $amt_max = 10 if $amt_max < 1;

    _lang();

    Doc->template('top_block')->{title} = $lang::remitter_title;

    # Временные платежи?
    my %p = Db->line("SELECT cash FROM pays WHERE mid=? AND category=3 LIMIT 1", $usr->{id});
    Db->ok or Error($lang::s_soft_error);
    %p && Error($lang::remitter_tmp_pay);

    # За сутки с клиентом делились балансом? блокируем чтоб не форвардили деньги туда-сюда
    my %p = Db->line("SELECT cash FROM pays WHERE mid=? AND category=30 AND time>(UNIX_TIMESTAMP()-24*3600)LIMIT 1", $usr->{id});
    Db->ok or Error($lang::s_soft_error);
    %p && Error($lang::remitter_block_chain);

    my($go, $ppc, $amt, $balance) = ses::input('go', 'ppc', 'amt', 'balance');

    if( ! $go )
    {
        my $msg = tmpl( \$lang::remitter_intro,
            input_ppc   => v::input_t( name=>'ppc', value=>$ppc, size=>8 ),
            input_amt   => v::input_t( name=>'amt', value=>$amt, size=>8 ),
            submit      => v::submit($lang::btn_go_next),
            f_commision => $fixed_commision,
            v_commision => $var_commision,
            amt_max     => $amt_max,
            amt_min     => $amt_min,
            gr          => $cfg::gr,
        );

        # Баланс для защиты от повторной отправки формы (фича юзабилити, не полная защита)
        Show MessageBox( $url->form( go=>1, balance=>$usr->{balance}, $msg ) );
        return 1;
    }

    my $url2 = $url->new( ppc=>$ppc, amt=>$amt );

    if( abs($balance-$usr->{balance})>0.01 )
    {
        $url2->redirect( -error=>1, -made=>$lang::remitter_duplicate );
        die;
    }

    $amt += 0;
    if( $amt <= 0 || $amt < $amt_min || $amt > $amt_max )
    {
        $url2->redirect( -error=>1, -made=>_($lang::remitter_err_amt, $amt_min, $amt_max) );
        die;
    }

    my $amt_with_commision = sprintf "%.2f", $amt + $amt*$var_commision/100 + $fixed_commision;

    if( $amt_with_commision > $usr->{balance} )
    {
        $url2->redirect( -error=>1,
            -made=>tmpl( \$lang::remitter_no_money,
                amt => $amt_with_commision,
                gr  => $cfg::gr,
            )
        );
        die;
    }

    my $send_uid = $usr->{id};
    my $recv_uid = $ppc;
    my $ppc_end = chop $recv_uid;
    if( Make_PPC($recv_uid) ne $ppc )
    {
        $url2->redirect( -error=>1, -made=>$lang::remitter_wrong_ppc );
        die;
    }
    if( $recv_uid == $send_uid )
    {
        $url2->redirect( -error=>1, -made=>$lang::remitter_same_uid );
        die;
    }

    my $ok;
    {
        Db->begin_work || last;

        Pay_to_DB(
            uid     => $send_uid,
            category=> 130,
            cash    => -$amt_with_commision,
            reason  => "remitter:$recv_uid:$amt",
        ) < 1 && last; 
 
        Db->do(
            "UPDATE users SET balance=balance-(?) WHERE id=? AND balance>? LIMIT 1",
            $amt_with_commision, $send_uid, $amt_with_commision,
        ) < 1 && last;

        Pay_to_DB(
            uid     => $recv_uid,
            category=> 30,
            cash    => $amt,
            reason  => "remitter:$send_uid",
        ) < 1 && last; 

        Db->do(
            "UPDATE users SET balance=balance+(?) WHERE id=? LIMIT 1",
            $amt, $recv_uid,
        ) < 1 && last;

        $ok = 1;
    }
    if( ! $ok || ! Db->commit )
    {
        Db->rollback;
        Error($lang::s_soft_error);
    }

    $url->redirect( a=>'u_main',
        -made => tmpl( \$lang::remitter_ok,
            amt => $amt,
            gr  => $cfg::gr,
            ppc => $ppc,
        )
    );
}

sub _lang
{
 $lang::remitter_title = 'Поделись балансом';

 $lang::remitter_intro = <<MSG;
    <div class='big h_center'>Услуга «поделиться балансом»</div>
    <p>Вы можете передать часть средств с вашего счета на счет другого абонента.</p>

    <p>
    {% if f_commision %}
        Фиксированная комиссия <b>{{f_commision}}</b> {{gr}}.
    {% endif f_commision %}

    {% if v_commision %}
        Комиссия <b>{{v_commision}} %</b>.
    {% endif v_commision %}
    
    Минимальная сумма перевода {{amt_min}} {{gr}}, максимальная {{amt_max}} {{gr}}.
    </p>

    <hr/>

    <div class='align_center'>
        <table class='td_narrow td_medium'>
            <tr><td class='h_right'>Персональный платежный код получателя</td><td>{{input_ppc}}</td></tr>
            <tr><td class='h_right'>Сумма перевода</td><td>{{input_amt}} {{gr}}</td></tr>
        </table>
    </div>

    <hr class='space'>

    <div class='align_center'>{{submit}}</div>
MSG

 $lang::remitter_tmp_pay    = 'Услуга недоступна пока активен временный платеж для вашей учетной записи';
 $lang::remitter_block_chain= 'Вы не можете перевести деньги на счет другого абонента т.к в течении суток '.
                                'сами получили финансы по этой же услуге. Попробуйте через время.';
 $lang::remitter_err_amt    = "Сумма должна быть в пределах [] .. [] $cfg::gr";
 $lang::remitter_no_money   = 'На вашем счету недостаточно финансов. Для перевода необходимо {{amt}} {{gr}}';
 $lang::remitter_wrong_ppc  = 'Неверный персональный платежный код получателя';
 $lang::remitter_same_uid   = 'Вы должны указать платежный код получателя, а не свой';
 $lang::remitter_duplicate  = 'Проверьте в истории платежей был ли перевод, если нет - повторите операцию';
 $lang::remitter_ok         = '{{amt}} {{gr}} отправлено на счет {{ppc}}';
}

1;
