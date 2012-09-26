#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use services;

sub go
{
 my($url,$usr) = @_;
 # set_next : выбор следующей услуги
 # add      : подключение услуги (по умолчанию)
 my $cmd = ses::input('cmd') eq 'set_next'? 'set_next' : 'add';

 if( $cmd eq 'add' )
 {
    Doc->template('top_block')->{title} = 'Подключение услуги';
 }
  else
 {
    Doc->template('top_block')->{title} = 'Автопродление услуги';
    # Пока не сделал в service.pm :)
    return 1;
 }

 my $err = services->proc(
    cmd         => $cmd,
    # по таблице user_services id уже подключенной услуги. Если cmd = 'add' - игнорируется 
    id          => ses::input_int('usr_service_id'),
    uid         => $usr->{id},
    service_id  => ses::input_int('service_id'),
    creator     => {
        type => 'user',
        id   => $usr->{id},
        ip   => $ses::ip,
    },
 );
 
 $url->redirect( a=>'u_main', -made=>(!$err? 'Выполнено' : $err->{for_usr} || $lang::s_soft_error) );
}

1;
