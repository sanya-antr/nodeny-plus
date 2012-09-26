#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

if( !$ses::ajax )
{
    Require_web_mod('user');
    return 1;
}

unshift @$ses::cmd, {
    id   => 'modal_window',
    data => _proc(),
};

return 1;

sub _proc
{
    my $uid = ses::input_int('uid');
    my $info = Get_usr_info($uid) or return $lang::err_try_again;
    $info->{id} or return "User id=$uid не найден в базе";
    Adm->chk_usr_grp($info->{grp}) or return "Нет доступа к группе user id=$uid";

    my @menu = ();

    push @menu, _('[] [filtr|bold] логин [filtr|bold], id [bold]',
        url->a('В новом окне', a=>'user', uid=>$uid, -target=>'_blank', -class=>'nav' ),
        $info->{fio},
        $info->{name},
        $uid,
    );

    my $links = '';
    if( Adm->chk_privil('pay_show') )
    {
        $links .= ' '.url->a('Платежи', a=>'pay_log', uid=>$uid, -class=>'nav');
    };

    $links .= ' '.url->a('Трафик', a=>'traf_log', uid=>$uid, -class=>'nav');

    push @menu, $links;

    my $url = url->new( a=>'ajPayCreate', uid=>$uid, -class=>'ajax' );
    my $input_amt = v::input_t( name=>'amt', value=>'', size=>6 );

    if( Adm->chk_privil('pay_tmp') )
    {
        my $c = 'tmp_pay_date';
        push @menu, $url->form( type=>'tmp',
            _('[] [] будет удален [] []',
                $input_amt,
                $cfg::gr,
                v::input_t(name=>'date', value=>'', size=>8, id=>$c),
                v::submit('Временный платеж'),
            )
        );
        push @$ses::cmd, {
            type => 'js',
            data => "\$('#$c').simpleDatepicker()",
        };
    }

    Adm->chk_privil('pay_cash') && push @menu,
        $url->form( type=>'cash',
            _('[] [] []',
                $input_amt,
                $cfg::gr,
                v::submit('Пополнить счет'),
            )
        );

    Adm->chk_privil('pay_bonus') && push @menu,
        $url->form( type=>'bonus',
            _('[] [] []',
                $input_amt,
                $cfg::gr,
                v::submit('Бонус'),
            )
        );



    if( Adm->chk_privil('msg_create') )
    {
        push @menu, $url->form( type=>'msg',
            _('[][div h_center]',
                v::input_ta('msg','',50,5),
                v::submit('Сообщение'),
            )
        );
    }

    return join '<hr>', @menu;
}

1;
