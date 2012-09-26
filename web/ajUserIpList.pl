#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head
    Для user <uid> оформляет в ввиде таблицы список его ip и
    посылает ее в DOM-элемент с id = <domid>
=cut

use strict;

push @$ses::cmd, {
    id   => ses::input('domid'),
    data => _proc(),
};

return 1;

sub _proc
{
    my $uid = ses::input_int('uid');

    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my $url_refresh = url->a('Обновить', -ajax=>1, a=>ses::cur_module, uid=>$uid, domid=>ses::input('domid'));

    my $msg = '';

    {   # --- Последний раз авторизовался методом ...
        # Смотрим и в лог авторизаций и в текущие авторизации, выбираем самую последнюю отметку времени
        my %p = Db->line(
            'SELECT properties, time FROM ('.
                '(SELECT properties, `end` AS time FROM auth_log WHERE uid=? ORDER BY `end` DESC LIMIT 1)'.
                    ' UNION ALL '.
                '(SELECT properties, `last` AS time FROM v_ips WHERE uid=? AND last IS NOT NULL ORDER BY `last` DESC LIMIT 1)'.
            ') tbl ORDER BY time DESC LIMIT 1',
            $uid, $uid
        );

        %p or last;
        my %property = map{ split /=/, $_ } split /;/, $p{properties};
        $property{mod} or last;
        $msg .= _('[div txtpadding]',
            _('Последняя авторизация [] методом [filtr|commas] []',
                the_short_time($p{time}), $property{mod}, url->a(['>>>'], uid=>$uid, a=>'u_auth_log')
            )
        );
    }

    my $db = Db->sql("SELECT * FROM v_ips WHERE uid=? ORDER BY ip", $uid);
    $db->ok or return _('[span error] []', 'Ошибка получения списка ip адресов.', $url_refresh);
    $db->rows or return '';

    my $auth_count = 0;
    my $tbl = tbl->new(-class=>'td_wide td_medium');

    while( my %p = $db->line )
    {
        my $ip = [ url->a($p{ip}, -ajax=>1, a=>'ajUserIpInfo', ipn=>$p{ipn}, uid=>$uid, domid=>ses::input('domid')) ];
        if( !$p{auth} )
        {
            $tbl->add('', 'llll', '', $ip, '', '', '');
            next;
        }
        $auth_count++;
        my %property = map{ split /=/, $_ } split /;/, $p{properties};
        my $auth = [ v::tag('img', src=>$cfg::img_url.'/on.gif') ];
        my($l_ip, $l_start, $l_period, $l_properties) = @lang::mUser_auth_header;
        $tbl->add('', [
            ['',    '',             $auth   ],
            ['',    $l_ip,          $ip     ],
            #['',    $l_start,       the_short_time($p{start}) ],
            ['',    $l_period,      the_hh_mm($ses::t-$p{start}) ],
            #['',    $l_properties,  $property{mod} ],
        ]);
    }
    return $tbl->show.$msg;
}
