#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package services::inet_unlim;
use strict;

sub description
{
    return 'Доступ в интернет на заданное время с заданной скоростью';
}

sub tunes
{
 my $fields = [
    {
        name    => 'mode',
        title   => 'Режим',
        type    => 20,
        hash    => { '' => 'стандарт', 1 => 'месяц', 2 => 'конец месяца' },
        comment =>  '<ul>'.
                    '<li>стандарт: услуга действует с момента активации и завершается по прошествии времени, указанном в поле `Срок действия`'.
                    '<li>месяц: длительность услуги меняется динамически от 28 до 31 дня в зависимости от количества дней в месяце'.
                    '<li>конец месяца: услуга действует с момента активации до конца месяца'.
                    '</ul>',
    },
    {
        name    => 'period',
        title   => 'Срок действия',
        type    => 11,
        comment => 'например, `31 01:30:00` - 31 день, 1 час и 30 минут',
        value   => 30*24*3600,
    },
    {
        name    => 'chkBalance',
        title   => 'Положительный баланс',
        type    => 6,
        comment => 'Если при продлении данной услуги у клиента недостаточно денег на счету, услуга не будет подключена. Вместо нее будет подключена `услуга по умолчанию`',
        value   => 0,
    },
    {
        name    => 'speed_in1',
        title   => 'Входящая скорость 1',
        type    => 1,
        comment => 'бит/сек. Скорость направления № 1 к клиенту',
        value   => 1024000,
    },
    {
        name    => 'speed_out1',
        title   => 'Исходящая скорость 1',
        type    => 1,
        comment => 'бит/сек. Если = 0, то входящий и исходящий трафик в одной трубе',
        value   => 1024000,
    },
    {
        name    => 'speed_in2',
        title   => 'Входящая скорость 2',
        type    => 1,
        comment => 'бит/сек',
    },
    {
        name    => 'speed_out2',
        title   => 'Исходящая скорость 2',
        type    => 1,
        comment => 'бит/сек. Если = 0, то входящий и исходящий трафик в одной трубе',
    },
    {
        name    => 'speed_in3',
        title   => 'Входящая скорость 3',
        type    => 1,
        comment => 'бит/сек',
    },
    {
        name    => 'speed_out3',
        title   => 'Исходящая скорость 3',
        type    => 1,
        comment => 'бит/сек. Если = 0, то входящий и исходящий трафик в одной трубе',
    },
    {
        name    => 'speed_in4',
        title   => 'Входящая скорость 4',
        type    => 1,
        comment => 'бит/сек',
    },
    {
        name    => 'speed_out4',
        title   => 'Исходящая скорость 4',
        type    => 1,
        comment => 'бит/сек. Если = 0, то входящий и исходящий трафик в одной трубе',
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

    my $tags = ',inet,speed,';
    $tags .= 'chkBalance,' if $service_new->{param}{chkBalance};

    $actions->{pay} = {
        cash    => 0 - $service_new->{price},
        comment => $service_new->{description},
        category=> 100,
        discount=> $service_new->{discount},
    };
    $actions->{set_service} = {
        period => int $service_new->{param}{period},
        mode   => int $service_new->{param}{mode},
        tags   => $tags,
    };
}

1;