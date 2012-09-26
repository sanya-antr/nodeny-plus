#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

my $Url = url->new();

my $uid;
my $info;
if( $ses::auth->{role} eq 'admin' )
{
    Adm->chk_privil(100) or Error($lang::s_err_no_stat_priv);
    $uid = ses::input_int('uid');
    $uid or Error($lang::s_no_usr_selected);
    $info = Get_usr_info($uid) or Error($lang::err_try_again);
    $info->{id} or Error($lang::s_no_usr_selected);
    Adm->chk_usr_grp($info->{grp}) or Error($lang::s_err_no_u_grp_priv);
    ToLeft MessageWideBox( $info->{full_info} );
    $Url->{uid} = $uid;
}
 else
{
    # Если произойдет критическая ошибка, то это сообщение будет выведено вместо описания ошибки, см. /cgi-bin/stat.pl
    $cfg::critical_error_msg = $lang::s_critical_error;
    $uid = $ses::auth->{uid};
    $info = Get_usr_info($uid) or Error($lang::s_soft_error);
    $info->{id} or Error($lang::s_soft_error);
    Doc->template('top_block')->{title} = $lang::s_title.' '.$cfg::net_title;
    push @{$ses::subs->{exit}}, \&_show_top_block;
}

our %U = %$info;

$ses::input->{a} ||= 'u_main';

if( $U{cstate} == 1 && scalar @cfg::request_info_from_usr )
{
    debug('Запись в состоянии `на подключении` - запросим контактные данные вне зависимости от команды');
    unshift @cfg::Plugins, 'req_info';
    $ses::input->{a} = 'u_req_info';
}

# В начало списка плагинов добавим `главная`
unshift @cfg::Plugins, 'main';

my $plugin_menu = '';
foreach my $cod( @cfg::Plugins )
{
    $cod = 'u_'.$cod;
    my $plg = $cfg::plugins->{$cod};
    if( ! $plg )
    {
        debug('warn', "В реестре плагинов нет плагина с кодом `$cod`");
        next;
    }
    $plg->{for_adm} && !Adm->id && next;
    $plg->{available} = 1;
    $plugin_menu .= $Url->a($plg->{descr}, a=>$cod);
}
$plugin_menu .= url->a($lang::btn_logout, a=>'logout');

ToLeft Menu($plugin_menu);

my $cmd = ses::input('a');

$cfg::plugins->{$cmd} or Error('Неверная операция');

if( $cfg::plugins->{$cmd}{ajax} && !$ses::ajax )
{
    debug('warn', "Команда $cmd выполняется в ajax-контексте, но http-запрос не ajax - выводим титульную страницу");
    $cmd = 'u_main';
}

$Url->{a} = $cmd;
$ses::input->{a} = $cmd;
my $err = Require_web_mod($cfg::plugins->{$cmd}{file});
$err && die $err;

# Выполним плагин
go( $Url, $info );

sub _show_top_block
{
    Doc->template('base')->{top_block} .= tmpl('usr_top_block', %{Doc->template('top_block')});
}

1;