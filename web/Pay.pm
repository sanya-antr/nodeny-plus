#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package Pay;
use strict;
use Debug;
use Db;

main->import( qw( _ ) );

my $err_data_is_corrupted = _('[span error]','Данные платежа повреждены');

my %category = (
    1 =>{
            title  => 'Наличный платеж',
            decode => \&decode_1,
    },
    2 =>{
            title  => 'Бонусный платеж',
            decode => \&decode_2,
    },
    3 =>{
            title  => 'Временный платеж',
            decode => \&decode_3,
    },
    20  => {
            title  => 'Оплата в платежной системе',
            decode => \&decode_pay_system,
    },
    30  => {
            title  => 'Перевод баланса с другого счета',
            decode => \&decode_30,
    },
    50  => {
            title  => 'Бонусная услуга',
            decode => \&decode_50,
    },
    99  => {
            title  => 'Карточки пополнения',
            decode => \&decode_99,
    },
    100  => {
            title  => 'Снятие за услуги',
            decode => \&decode_100,
    },
    130  => {
            title  => 'Перевод баланса на другой счет',
            decode => \&decode_130,
    },
    200 => {
            title  => 'Удаление временного платежа',
            decode => \&decode_200,
    },
    220 => {
            title  => 'Удаление учетной записи клиента',
            decode => \&decode_standart_dump,
    },
    250 => {
            title  => 'Проверка системы. Уровень : количество проблем',
            decode => \&decode_standart_dump,
    },
    300 => {
            title  => 'Карточки NoDeny: генерация',
            decode => \&decode_300,
    },
    301 => {
            title  => 'Карточки NoDeny: изменение состояния',
            decode => \&decode_301,
    },
    305 => {
            title  => 'Карточки NoDeny: код не существует',
            decode => \&decode_305,
    },
    406 => {
            title  => 'Дострочное завершение услуги',
            decode => \&decode_406,
    },
    410 => {
            title  => 'Изменение данных клиента',
            decode => \&decode_standart_dump,
    },
    411 => {
            title  => 'Создание учетки клиента',
            decode => \&decode_standart_dump,
    },
    412 => {
            title  => 'Изменение допданных клиента',
            decode => \&decode_standart_dump,
    },
    423  => {
            title  => 'Блокировка по задолженности',
            decode => {
                for_adm => 'Заблокирован т.к. баланс [] &lt; []',
                for_usr => 'Заблокирован т.к. баланс [] &lt; []',
            },
    },
    444 => {
            title  => 'Заявка на оплату в платежной системе',
            decode => \&decode_pay_system,
    },
    445 => {
            title  => 'Заявка на оплату принята платежной системой',
            decode => \&decode_pay_system,
    },
    446 => {
            title  => 'Неуспешная оплата в платежной системе',
            decode => \&decode_pay_system,
    },
    480 => {
            title  => 'Сообщение клиенту',
            decode => \&decode_msg_to_usr,
    },
    481 => {
            title  => 'Клиент ознакомился с сообщением',
            decode => \&decode_msg_to_usr,
    },
    491 => {
            title  => 'Сообщение клиента',
            decode => {
                for_adm => 'Сообщение клиента [div small_msg]',
                for_usr => 'Ваше сообщение [div small_msg]',
            },
    },
    492 => {
            title  => 'Сообщение клиента',
            decode => {
                for_adm => 'Сообщение клиента [div small_msg]',
                for_usr => 'Ваше сообщение [div small_msg]',
            },
    },

    550 => {
            title  => 'Создание администратора',
            decode => {
                for_adm => 'Создание администратора id = []',
                for_usr => '',
            },
    },

    551 => {
            title  => 'Изменение данных админа',
            decode => \&decode_standart_dump,
    },

    552 => {
            title  => 'Удаление администратора',
            decode => {
                for_adm => 'Удален администратор id = []',
                for_usr => '',
            },
    },

);



sub decode
{
    my($pay) = @_;
    my $param = $category{$pay->{category}};
    my $reason = $pay->{reason};
    $param or return {
        for_adm => _('[span error] []', 'Неизвестная категория ', $pay->{category}),
        for_usr => '',
    };
    my $decode = $param->{decode};
    if( ref $decode eq 'HASH' )
    {
        # копия!
        $decode = {%{$decode}};
        $decode->{for_adm} = main::_($decode->{for_adm}, split /:/, $reason);
        $decode->{for_usr} = main::_($decode->{for_usr}, split /:/, $reason);
        #foreach my $r( split /:/, $reason )
        #{
        #    $decode->{for_adm} =~ s/\[\]/$r/;
        #    $decode->{for_usr} =~ s/\[\]/$r/;
        #}
        return $decode;
    }
    return &{$decode}($reason, $pay, $param);
}

sub category
{
    my($category) = @_;
    return $category{$category}->{title};
}

# -----------------------------------------------

sub _eval
{
    my($data) = @_;
    local $SIG{'__DIE__'} = {};
    my $VAR1;
    eval $data;
    if( $@ )
    {
        debug('error', {code=>$data, error=>"$@"});
        return '';
    }
    ref $VAR1 eq 'HASH' or return '';
    return $VAR1;
}

sub decode_standart_dump
{
    my($reason, $pay, $param) = @_;
    my $data = _eval( $reason );
    $data or return {
        for_adm => $err_data_is_corrupted." (pay id: $pay->{id})",
        for_usr => '',
    };
    my $tbl = tbl->new( -class=>'td_wide td_medium thead', -row1=>'row4', -row2=>'row5' );
    foreach my $k( keys %$data )
    {
        $tbl->add('*', [
            ['', 'Поле',     $k ],
            ['', 'Значение', $data->{$k} ],
        ]);
    }
    my $for_adm = $param->{title}.'<br><br>'.$tbl->show;
    return {
        for_adm => $for_adm,
        for_usr => '',
    };
}

sub decode_30
{
    my($reason, $pay, $param) = @_;
    my($module, $send_uid) = split /:/, $reason;
    return {
        for_adm => main::_('Перевод со счета абонента id [filtr] модулем [filtr|commas]', $send_uid, $module),
        for_usr => main::_('Перевод со счета абонента id [filtr]', $send_uid),
    };
}

sub decode_50
{
    my($reason, $pay, $param) = @_;
    return {
        for_adm => 'Бонус: '.$pay->{comment},
        for_usr => 'Бонус: '.$pay->{comment},
    };
}

sub decode_99
{
    my($reason, $pay, $param) = @_;
    return {
        for_adm => "Пополнение карточкой: $reason",
        for_usr => 'Пополнение счета скретч-картой',
    };
}


sub decode_100
{
    my($reason, $pay, $param) = @_;
    my $comment = $pay->{comment};
    $comment =~ s/\n/<br>/g;
    my $p = _eval( $reason );
    my @comments = ($comment);
    if( $p )
    {
        if( defined $p->{cash} && abs($p->{cash}-$pay->{cash})>0.01 )
        {
            push @comments, _('Полная стоимость услуги: [][]', abs($p->{cash}), $cfg::gr);
        }
        if( $p->{tm_start} && $p->{tm_end} )
        {
            push @comments, _('Срок действия: [] .. []',
                main::the_time($p->{tm_start}),
                main::the_time($p->{tm_end})
            );
        }
        if( $p->{discount} )
        {
            push @comments, _('Скидка []%', $p->{discount});
        }
        if( $p->{last_day_k} )
        {
            push @comments, _('Неполный месяц, коэффициент: []', $p->{last_day_k});
        }
        
        $comment = join '<br>', @comments;
    }
    return {
        for_adm => $comment,
        for_usr => $comment,
    };
}

sub decode_130
{
    my($reason, $pay, $param) = @_;
    my($module, $recv_uid, $amt) = split /:/, $reason;
    return {
        for_adm => main::_('Перевод [filtr] [] на счет абонента id [filtr] модулем [filtr|commas]', $amt, $cfg::gr, $recv_uid, $module),
        for_usr => main::_('Перевод [filtr] [] на счет абонента id [filtr]', $amt, $cfg::gr, $recv_uid),
    };
}

sub decode_406
{
    my($reason, $pay, $param) = @_;
    my $pay_id = int $reason;
    my $for_adm = main::_('Дострочное завершение услуги pay_id: []', $pay_id);
    return {
        for_adm => $for_adm,
        for_usr => '',
    };
}

sub decode_200
{
    my($reason, $pay, $param) = @_;
    my $amt = $reason + 0;
    my $for_adm = main::_('Удален временный платеж в размере [] []', $amt, $cfg::gr);
    return {
        for_adm => $for_adm,
        for_usr => '',
    };
}

sub decode_300
{
    my($reason, $pay, $param) = @_;
    my($start, $end, $amt, $count) = split /:/, $reason;
    my $for_adm = main::_(
        'Сгенерировано [] карточек оплаты номиналом [] [], диапазон: []..[]',
        $count, $amt, $cfg::gr, $start, $end
    );
    return {
        for_adm => $for_adm,
        for_usr => '',
    };
}

sub decode_301
{
    my($reason, $pay, $param) = @_;
    my($start, $end, $count, $alive) = split /:/, $reason;
    my $for_adm = main::_('[filtr] карточек оплаты в диапазоне [filtr] .. [filtr] переведены в состояние [filtr|commas]',
        $count, $start, $end, $lang::card_alives->{$alive} || $alive);
    return {
        for_adm => $for_adm,
        for_usr => '',
    };
}

my %liqpay_pay_ways = (
    liqpay  => 'валюта Liqpay',
    card    => 'пластиковая карта',
    delayed => 'наличными в терминале',
);
sub decode_pay_system
{
    my($reason, $pay, $param) = @_;
    my($payment_system, $time, $amt, @other) = split /:/, $reason;
    my $for_adm = main::_(
        '[] [commas] на сумму [] [], была создана []',
        $param->{title}, $payment_system, $amt, $cfg::gr, main::the_time($time)
    );
    # Если оплата успешная, то комментарий покажем клиенту
    my $for_usr = $pay->{category}==20? $for_adm : '';
    # Детали только админу
    if( $payment_system eq 'liqpay' && defined $other[0] )
    {
        $for_adm .= main::_(', телефон [commas], id транзакции в Liqpay [], способ оплаты [commas]',
            $other[0], $other[1], $liqpay_pay_ways{$other[2]} || $other[2]);
    }
    return {
        for_adm => $for_adm,
        for_usr => $for_usr,
    };
}

sub decode_msg_to_usr
{
    my($reason, $pay, $param) = @_;
    return {
        for_adm => _('[][div small_msg]', $param->{title}.': ', $pay->{comment}),
        for_usr => _('[][div small_msg]', 'Сообщение от администрации: ', $pay->{comment}),
    };
}

sub decode_305
{
    my($reason, $pay, $param) = @_;
    my $cod = $reason;
    my $for_adm = main::_('На момент попытки активации введеный код пополнения [commas] отсутствовал в БД.', $cod);
    return {
        for_adm => $for_adm,
        for_usr => '',
    };
}

sub decode_1
{
    my($reason, $pay, $param) = @_;
    my $for_adm = $param->{title};
    my $comment = $pay->{comment};
    $comment =~ s/\n/<br>/g;
    $for_adm .= _('. Комментарий, который увидит клиент: []',$comment) if $comment;
    return {
        for_adm => $for_adm,
        for_usr => $pay->{comment},
    };
}

sub decode_2
{
    my($reason, $pay, $param) = @_;
    my $for_adm = $param->{title};
    my $comment = $pay->{comment};
    $comment =~ s/\n/<br>/g;
    $for_adm .= _('. Комментарий, который увидит клиент: []',$comment) if $comment;
    return {
        for_adm => $for_adm,
        for_usr => $pay->{comment} || $param->{title},
    };
}

sub decode_3
{
    my($reason, $pay, $param) = @_;
    my $tm_create = int $reason;
    my $for_all = main::_('Временный платеж. Создан [], будет удален []',
        main::the_time($tm_create), main::the_time($pay->{time}));
    my $comment = $pay->{comment};
    $comment =~ s/\n/<br>/g;
    $for_all .= '<br>'.$comment if $comment;
    return {
        for_adm => $for_all,
        for_usr => $for_all,
    };
}


1;
