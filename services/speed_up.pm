#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package services::speed_up;
use strict;

sub description
{
    return 'Повышает скорость в интернет на определенное время. '.
        'Клиент сможет подключить услугу только, если у него уже подключена услуга с доступом в интернет';
}

sub tunes
{
 my $fields = [
    {
        name    => 'period',
        title   => 'Срок действия',
        type    => 11,
        comment => '`31 01:30:00` - 31 день, 1 час и 30 минут',
        value   => 1*24*3600,
    },
    {
        name    => 'speed_up1',
        title   => 'Повышение скорости 1',
        type    => 3,
        comment => 'Увеличения скорости направления № 1 во столько раз',
        value   => 2,
    },
    {
        name    => 'speed_up2',
        title   => 'Повышение скорости 2',
        type    => 3,
        value   => 1,
    },
    {
        name    => 'speed_up3',
        title   => 'Повышение скорости 3',
        type    => 3,
        value   => 1,
    },
    {
        name    => 'speed_up4',
        title   => 'Повышение скорости 4',
        type    => 3,
        value   => 1,
    },
 ];

 return $fields;
}

sub set_service
{
    my(undef, %p) = @_;
    my $uid         = $p{uid};
    my $service_new = $p{service_new};
    my $actions     = $p{actions};

    Db->line("SELECT 1 FROM v_services WHERE uid=? AND tags LIKE '%,inet,%'", $uid);

    if( !Db->ok )
    {
        $actions->{error} = {
            for_adm => 'не выполнен sql поиска услуги с тегом inet',
            for_usr => 'временная ошибка',
        };
        return;
    }

    if( Db->rows < 1 )
    {
        $actions->{error} = {
            for_adm => 'данная услуга повышает скорость только если у клиента подключена услуга, дающая доступ в интернет.',
            for_usr => 'услуга повышает скорость только если у вас подключена услуга, дающая доступ в интернет.',
        };
        return;
    }

    $actions->{pay} = {
        cash    => 0 - $service_new->{price},
        comment => $service_new->{description},
        category=> 100,
    };
    $actions->{set_service} = {
        period  => int $service_new->{param}{period},
        tags    => ',inet,speed,',
    };
}

1;