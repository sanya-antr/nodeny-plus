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
 Doc->template('top_block')->{title} = 'Подключение услуги';

 # Услуги каких модулей уже подключены клиенту
 my %this_usr_modules = ();
 my %this_usr_servises = ();
 my $db = Db->sql( "SELECT service_id, module FROM v_services WHERE uid=?", $usr->{id} );
 Db->ok or Error($lang::s_soft_error);
 while( my %p = $db->line )
 {
    $this_usr_modules{$p{module}} = 1;
    $this_usr_servises{$p{service_id}} = 1;
 }

 # Получим все услуги с декодированными данными поля param
 my $services = services->get( decode=>1 );
 $services or Error($lang::s_soft_error);
 
 my $usr_grp = $usr->{grp};
 my $tbl = tbl->new( -class=>'td_tall td_wide' );
 foreach my $module( keys %$services )
 {
    foreach my $service( @{$services->{$module}} )
    {
        $service->{grp_list} =~ /,$usr_grp,/ or next;
        $service->{price} > 0 or next;

        my $param = $service->{param};
        keys %$param or next; # параметры не декодированы (повреждены)

        my $period = $param->{month}?  'месяц' :
                     $param->{period}? the_hh_mm($param->{period}) :
                     'неограничен';

        my $info =
            $this_usr_servises{$service->{service_id}}? _('[span data1]','Подключена') :
            $this_usr_modules{$service->{module}}? "<acronym title='Уже подключена аналогичная'>Недоступна</acronym>" :
            $url->a('Подключить', a=>'u_srv_add', service_id=>$service->{service_id});

        $tbl->add( '*', 'lrrl',
            [ $info ],
            $service->{price},
            $period,
            $service->{description},
        )
    }
 }
 $tbl->rows or Error('В данный момент не доступно ни одной услуги');

 $tbl->ins('head', 'lrrl', '', "Стоимость, $cfg::gr", 'Период действия', 'Описание');

 Show $tbl->show;
}

1;
