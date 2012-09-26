#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use services;

my $res = _proc();

$res && push @$ses::cmd, {
    id   => ses::input('domid'),
    data => _('[div small_msg]',$res),
};

return 1;

sub _proc
{
    Adm->chk_privil_or_die(90);

    my $uid = ses::input_int('uid');
    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    # add - подключение услуги
    # set_next - изменение поля `следующая услуга` в существубщей услуге
    my $cmd = ses::input('cmd') eq 'set_next'? 'set_next' : 'add';
    my $id  = ses::input_int('id');

    # domid ссылается на список отображаемых услуг, если что - обновим его
    my $url = url->new( a=>ses::cur_module, uid=>$uid, id=>$id, cmd=>$cmd, domid=>ses::input('domid'), -ajax=>1 );

    # --- Непосредственная установка услуги ---
    {
        ses::input_exists('service_id') or last;
        my $service_id = ses::input_int('service_id');

        my $err = services->proc(
            cmd         => $cmd,
            id          => $id,
            uid         => $uid,
            service_id  => $service_id,
            creator     => {
                type => 'admin',
                id   => Adm->id,
                ip   => $ses::ip,
            },
        );

        if( $err )
        {
            return _('Ошибка:[p][p]',
                $err->{for_adm},
                'Если ошибка устойчивая - к администратору (см. Debug)'
            );
        }

        Require_web_mod('ajUserSrvList');
        return '';
    }

    # Получим список всех услуг, сгруппированных по модулю, декодирование поля param не производим
    my $services = services->get( decode=>0 );
    # Если  что-то не так, например с БД
    $services or return $lang::err_try_again;
    keys %$services or return 'Не существует ни одной услуги';

    # Если все существующие услуги одного модуля - шаг запроса модуля услуг (`тип услуги`) пропускаем
    my $module = ses::input('module');
    if( keys %$services == 1 )
    {   
        ($module) = keys %$services;
    }

    my $menu = '';

    # Установка поля `следующая услуга`. Присланный cur_service_id не проверяем т.к будет проверка при установке
    if( $cmd eq 'set_next' )
    {
        my %p = Db->line("SELECT * FROM v_services WHERE uid = ? AND id = ?", $uid, ses::input_int('id'));

        $menu .= _('[p]', 'Автопродление'.($p{next_service_id}? ' включено' : ' выключено'));
        
        $menu .= _('[div][div]',
            $url->a( 'Не продлевать', service_id=>0 ),
            $url->a( 'Продлить текущей', service_id=>ses::input_int('cur_service_id') ),
        );
    }

    # --- Список услуг типа $module ---
    {
        $module or last;
        my $services_of_module = $services->{$module};
        ref $services_of_module or last; # такого типа услуг не существует
        scalar @$services_of_module or return 'Нет ни одной услуги данного типа';
        my $tbl = tbl->new( -class=>'td_ok' );
        foreach my $service( @$services_of_module )
        {
            my $price = $service->{price};
            $tbl->add( '', 'lll',
                [ $url->a( $service->{title}, service_id=>$service->{service_id} ) ],
                $price>=0? $price : 'бонус '.(-$price),
                $cfg::gr
            );
        }

        $menu .= _('[p]', $cmd eq 'set_next'? 'Продлить услугой:' : 'Выберите услугу');
        $menu .= $tbl->show;
        $menu .= _('[p]', $url->a('Вернуться', module=>undef));
        return $menu;
    }

    # --- Список типов услуг ---
    {
        my $module_list = '';
        foreach my $module( keys %$services )
        {
            $module_list .= $url->a( $module, module=>$module, cur_service_id=>ses::input_int('cur_service_id') );
        }
        $menu .= _('[p][div mUser_service_list]', 
            $cmd eq 'set_next'? 'Продлить услугой типа:' : 'Выберите тип услуги',
            $module_list
        );
        $menu .= _('[p]',
            $url->a('Вернуться', a=>'ajUserSrvList').' | '.
            url->a('Помощь', a=>'help', theme=>'srv_renew', -ajax=>1)
        );
        return $menu;
    }

}


1;