#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
 my($Url) = @_;

 $ses::debug && debug('head', "mysql: ".Db->dbh->{mysql_stat});

 Doc->template('top_block')->{title} = _($lang::mTitle_hello_adm, Adm->name || Adm->login);

 my $Aid = Adm->id;
 my $SuperAdmin = Adm->chk_privil('SuperAdmin');

 my $out = '';

 foreach my $p(
    [ 'usr_create', 'Новый клиент', a=>'user_new' ],
    [ 'topology',   'Карта', a=>'yamap' ],
    [ 'cards',      'Карточки пополнения счета', a=>'cards' ],
    [ 'on',         'Графики авторизаций', a=>'auth_log' ],
    [ 'report',     'Графики', a=>'graphs' ],
 ){
    my $priv = shift @$p;
    Adm->chk_privil($priv) or next;
    $out .= url->a(@$p);
 }
 if( $SuperAdmin || Adm->chk_privil('Admin') )
 {
    $out .= url->a('Администраторы', a=>'admin') ;
    $out .= url->a('Настройки', a=>'tune');
 }

 ToLeft Menu($out);

 my $ul = '';
 sub li {
    $ul .= _('[p|li]', $_[0]);
 }

 $ses::cookie->{new_admin} && li(
    url->a('Переключиться на свою учетку', set_new_admin=>'')
 );

 $SuperAdmin && li(
    $ses::cookie->{debug}? url->a('Отключить debug-режим', set_debug=>'') :
        url->a('Включить debug-режим', set_debug=>1)
 );

 $SuperAdmin && $ses::auth->{adm}{trust} && li(
    url->a('Переключиться в безопасный режим', a=>'safe_ses')
 );

 $ENV{SERVER_PORT} && !$ENV{HTTPS} && li( 
    _('[span warn] []','Предупреждение:','вы НЕ работаете по защищенному протоколу https.')
 );

 # -------------------------- Карточки пополнения --------------------------

 my @f = (
  [ 'adm_owner=? AND adm_move=0',   'числятся за вами' ],
  [ 'adm_owner=? AND adm_move<>0',  'вы передали другому админитратору, но он пока не подтвердил это' ],
  [ 'adm_move=?',                   'переданы вам и вы должны это подтвердить' ],
 );

 my $url2 = url->new();
 foreach my $p( @f )
 {
    my $db = Db->sql("SELECT COUNT(*) AS n, alive FROM cards WHERE $p->[0] GROUP BY alive", $Aid);
    my($list, $count) = ('', 0);
    while( my %p = $db->line )
    {
        $list .= _('[li]', "$p{n} шт в состоянии `$lang::card_alives->{$p{alive}}`");
        $count += $p{n};
    }
    $list && li $url2->a("$count карточек пополнения счета", a=>'cards', act=>'list', aid=>$Aid)." $p->[1]: ".
            _('[ul]',$list);
    $url2->{move} = 1;
 }

 # --- Текущие авторизации ---
 {
    my $db = Db->sql(
        'SELECT COUNT(*) AS n, ROUND((UNIX_TIMESTAMP()-last)/10)*10 AS tm FROM auth_now GROUP BY tm ORDER BY tm'
    );
    $db->rows > 0 or last;
    my $tbl = tbl->new( -class=>'td_ok', -row1=>'row4', -row2=>'row5' );
    while( my %p = $db->line )
    {
        $tbl->add('*', [
            [ 'h_center',   'Секунд назад', $p{tm}.' .. '.($p{tm}+9) ],
            [ 'h_center',   'Авторизаций',  $p{n} ],
        ]);
    }
    li('Обновление авторизаций'.$tbl->show);
 }

 # --- Список админов, на которых можно переключиться ---
 {
    $SuperAdmin or last;
    my $db = Db->sql("SELECT * FROM admin ORDER BY login");
    my $tbl = tbl->new( -class=>'td_tall td_wide', -row1=>'row4', -row2=>'row5' );
    $tbl->add('head','ccccc','','Логин','Имя','Админ?','Установить сообщение');
    while( my %p = $db->line )
    {
        my %pr = ();
        $pr{$_} = 1 foreach( split /,/,$p{privil} );
        $pr{1} or next;
        my $aid = $p{id};
        my $adm_login = $Url->a($p{login}, set_new_admin=>$aid);
        my $adm_super = $pr{3}? 'Super': $pr{2}? $lang::yes  : '';
        my $adm_msg = $Url->a($p{mess}=~/^\s*$/? 'установить':'*** изменить ***', a=>'operations', act=>'setmess', aid=>$aid);
        $tbl->add('*',' llcc',
            '',
            [$adm_login],
            $p{name},
            [$adm_super],
            [$adm_msg],
        );
    }
    $tbl->{data} && li('У вас есть право переключиться на любую из перечисленных учетных записей'.$tbl->show);
 }


 # --- Балансы Liqpay ---
 {
    $SuperAdmin or last;
    $cfg::liqpay_merch_id or last;
    my $domid = v::get_uniq_id();
    my $link = url->a('Получить балансы Liqpay', a=>'ajLiqBalances', domid=>$domid, -ajax=>1);
    li( _("[div id=$domid]",$link) );
 }

 # --- TurboSms ---
 {
    $SuperAdmin or last;
    $cfg::turbosms_db_pass or last;
    my $domid = v::get_uniq_id();
    my $link = url->a('Отправить sms', a=>'ajTurboSms', domid=>$domid, -ajax=>1);
    li( $link._("[div id=$domid]") );
    my $link = url->a('Состояние TurboSms', a=>'TurboSms');
    li( $link );
 }

 li("<a href='http://nodeny.com.ua'>Сайт NoDeny</a>");
 li("<a href='http://forum.nodeny.com.ua'>Форум техподдержки</a>");

 Show MessageWideBox( _('[ul]',$ul) );

}
1;
