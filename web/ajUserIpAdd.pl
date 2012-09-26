#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

my $res = _proc();

$res && push @$ses::cmd, {
    id   => ses::input('domid'),
    data => $res,
};

return 1;

sub _proc
{
    Adm->chk_privil_or_die('edt_usr');
    Adm->chk_privil_or_die(81);

    my $uid     = ses::input_int('uid');
    my $ip      = ses::input('ip');
    my $realip  = ses::input_int('realip');

    # Группа клиента
    my $grp;
    {
        my %u = Db->line("SELECT grp FROM users WHERE id=?", $uid);
        Db->ok or return $lang::err_try_again;
        %u or return "User id=$uid не найден в базе";
        $grp = $u{grp};
        Adm->chk_usr_grp($grp) or return "Нет доступа к группе user id=$uid";
    }

    # Какие сети разрешены в группе клиента
    my $nets = join "\n", '10.0.0.0/8','192.168.0.0/16', '0.0.0.0/0'; # если любые ip разрешены
    {
        my %p = Db->line("SELECT grp_nets FROM user_grp WHERE grp_id=?", $grp);
        Db->ok or return $lang::err_try_again;
        %p or last;
        $p{grp_nets} =~ /\d/ or next;
        $nets = $p{grp_nets};
    }

    # Sql выборки списка ip для отображения или для непосредственной установки клиенту
    my $sql = '';
    my @sql_param = ();
    foreach my $net( split /\n/, $nets )
    {
        if( $net !~ s|^\s*(\d+\.\d+\.\d+\.\d+)\/(\d+)\s*$|$1| || $2 > 32 )
        {
            debug('warn', 'В настройках группы не имеет формат xx.xx.xx.xx/xx сеть:', $net);
            next;
        }
        my $mask = $2;
        my $ip_is = "ip >= INET_ATON(?) AND ip <= (INET_ATON(?) + POWER(2, 32-?))";
        if( $ip )
        {   # установка ip
            $sql .= "OR ($ip_is)";
            push @sql_param, $net, $net, $mask;
        }
         else
        {   # получения списка ip
            $sql .= "UNION " if $sql;
            $sql .= "(SELECT ip, INET_NTOA(ip) AS ipa FROM ip_pool ".
                    "WHERE uid=0 AND type='static' AND $ip_is AND realip=? ORDER BY ip LIMIT 4)\n";
            push @sql_param, $net, $net, $mask, $realip;
        }
    }
    scalar @sql_param or return 'Неправильно задан список сетей в настройках группы клиента';

    if( $ip )
    {
        $ip =~ s/ //g;
        $ip =~ /^\d+\.\d+\.\d+\.\d+$/ or return _('ip [filtr|commas] указан некорректно', $ip);

        my $rows = Db->do(
            "UPDATE ip_pool SET uid=? WHERE uid=0 AND type='static' AND ip=INET_ATON(?) AND (0 $sql) LIMIT 1",
            $uid, $ip, @sql_param
        );
        if( $rows<1 )
        {
            my $err_msg = _('[span error]: ',"Ip $ip не добавлен");
            my %p = Db->line("SELECT * FROM ip_pool WHERE ip=INET_ATON(?)", $ip);
            Db->ok or return $lang::err_try_again;
            %p or return $err_msg.'он не существует в пуле ip адресов';
            $p{uid} && return $err_msg.' принадлежит другому клиенту';
            $p{type} ne 'static' && return $err_msg.' не статический';
            $nets =~ s/\n/<br>/g;
            return $err_msg._('возможно не попадает в список разрешенных у данной группы клиентов:[p]',$nets);
        }
        Require_web_mod('ajUserIpList');
        return '';
    }

    my $db = Db->sql("$sql ORDER BY ip", @sql_param);
    $db->ok or return $lang::err_try_again;
    $db->rows or return _('[p][p]',
        $realip? 'В пуле ip нет свободного статического реального адреса' : 'В пуле ip адресов нет свободного статического.',
        'Попросите суперадмина сгенерировать еще, либо освободить зарезервированные ip'
    );

    my $url = url->new( -base=> url->url( a=>ses::cur_module, uid=>$uid, domid=>ses::input('domid')) );
    my($out, $subnet);
    while( my %p = $db->line )
    {
        $out .= $url->a($p{ipa}, ip=>$p{ipa}, -ajax=>1);
        $subnet && next;
        $subnet = $p{ipa};
        $subnet =~ s/\.\d+$//;
    }
    $out .= $url->form( -class=>'ajax', v::input_t( name=>'ip', value=>$subnet).' '.v::submit('Ok') );
    $out = _('[div navmenu]', $out);
    return $out;
}





1;