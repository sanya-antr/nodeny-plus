#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package noserver::shapes;
use strict;
use Debug;

our @ISA = qw{noserver};

my $Users_services = {};

# Подпишемся на событие `получена информация клиентов`
noserver->Event_add('load_usr_info', \&load_usr_info);

sub load_usr_info
{
    my($M, $event) = @_;
    # Каждые 12 секунд выбираем все услуги с тегом speed
    {
        $M->Protect_time(12, 'usr_services') or last;
        my $db = Db->sql("SELECT uid, param FROM v_services WHERE tags LIKE '%,speed,%'");
        $db->ok or last;
        $Users_services = {};
        while( my %p = $db->line )
        {
            my $VAR1;
            eval $p{param};
            if( $@ )
            {
                debug('error', 'Параметры услуги повреждены:', "$@");
                next;
            }
            # На клиенте может быть несколько услуг с тегом speed, данные объединяем
            $Users_services->{$p{uid}} ||= {}; # ! иначе $srv = undef
            my $srv = $Users_services->{$p{uid}};
            map{ $srv->{$_} = $VAR1->{$_} } keys %$VAR1;
        }
    }
    my $usr = $M->{users};
    # Пройдемся по всем клиентам, которым включен доступ
    foreach my $uid( keys %$usr )
    {
        exists $Users_services->{$uid} or next;
        my $speed = $Users_services->{$uid};
        foreach my $dir( qw{ speed_in1 speed_in2 speed_in3 speed_in4 speed_out1 speed_out2 speed_out3 speed_out4 } )
        {
            exists $speed->{$dir} or next;
            $usr->{$uid}{$dir} = $speed->{$dir} if $speed->{$dir} > $usr->{$uid}{$dir};
        }
        foreach my $dir( 1..4 )
        {
            my $k = $speed->{"speed_up$dir"};
            if( $k && $k != 1 )
            {
                $usr->{$uid}{"speed_in$dir"} *= $k;
                $usr->{$uid}{"speed_out$dir"} *= $k;
            }
        }
    }
}

1;