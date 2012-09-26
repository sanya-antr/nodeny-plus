#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

$cfg::main_config = '/usr/local/nodeny/sat.cfg';

# Только для отладки
$ses::debug = 0;


$cfg::dir_home = $cfg::main_config;
$cfg::dir_home =~ s|/[^/]+$||;
$cfg::dir_web  = $cfg::dir_home.'/web';

unshift @INC, $cfg::dir_home;

$ses::ajax = $ENV{HTTP_X_REQUESTED_WITH} eq 'XMLHttpRequest';

eval "use Debug";
eval "use web::calls";

Require_web_mod('lang/'.$cfg::Lang.'_cap') && Error('NoDeny Internal Error');

Db->is_connected or Error($lang::cap::fatal_error);

# Через 10 секунд редиректим на страницу, которую запрашивал клиент.
# Например, клиент открыл браузер и там куча вкладок, в которых "не авторизовался!",
# после соединения по pppoe все вкладки будут перезагружены запршенными страницами
Doc->template('base')->{head_tag} .= v::tag('meta',
 'http-equiv'=>'refresh', content=>'10; url='.ses::input('url')
) if ses::input('url') ne '';

my %p = Db->line(<<SQL
SELECT
  IF(a.start IS NULL AND u.lstate = 0,0,1) AS auth,
  EXISTS( SELECT uid FROM users_services
    WHERE uid=u.id AND tags LIKE '%,inet,%') AS inet,
  i.uid, INET_NTOA(i.ip) AS ip, u.state
FROM ip_pool i
LEFT JOIN auth_now a ON INET_NTOA(i.ip)=a.ip
LEFT JOIN users u ON i.uid=u.id
WHERE INET_NTOA(i.ip)=?
SQL
, $ses::ip);

Db->ok or Error($lang::cap::fatal_error);
if( !%p )
{
    #tolog("Unknown ip: $ses::ip");
    Error_($lang::cap::wrong_ip, $ses::ip);
}

$p{auth} or Error_($lang::cap::no_auth);

$p{state} eq 'on' or Error_($lang::cap::state_off);

$p{inet} or Error_($lang::cap::no_inet);

Error_($lang::cap::ok);

Exit();