#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head
    Модуль авторизации.

    Генерится уникальный ключ (unikey) и по нему в таблицу webses_data в поле data записывается дамп:
        __auth__ =>  { salt => <соль>, url_param => <данные url> }

    соль        : случайная строка
    данные url  : все данные из url чтобы вернуться на страницу, которая была до авторизации (например: a=>'user', uid=>5 )

    Браузеру посылается форма с _unikey = <unikey>, _salt = <соль>, _hash = 'error'

    При сабмите формы, браузер посылает:
        _hash   = md5( <соль> + ' ' + <пароль> )
        _uu     = <имя пользователя>
        _unikey = <unikey>

    Если браузер присылает _hash = 'error' - значит js у него выключен.

    Когда call.pm видит параметр _unikey, дамп из поля data таблицы webses_data декомпилируется в $ses::data. Таким образом, 
        $ses::data = { __auth__ => { salt => <соль>, url_param => <данные url> } };

    Если _hash == md5( $ses::data->{__auth__}{salt} + ' ' + <пароль> ) - авторизация успешна
=cut

use strict;

Doc->template('base')->{main_v_align} = 'middle';

{
    ses::input('_hash') eq '' && last;
    ses::input('_uu') eq '' && last;
    ref $ses::data->{__auth__} or last;
    my $salt = $ses::data->{__auth__}{salt} or last;

    # Не даем авторизоваться больше одного раза по одному __salt__
    my $rows = Db->do("DELETE FROM webses_data WHERE unikey=? LIMIT 1", $ses::unikey);
    $rows>0 or Error('Temporary error');

    foreach my $h(
        [ 'user',  "SELECT id, AES_DECRYPT(passwd,?) AS pass FROM users WHERE BINARY name=? LIMIT 1" ],
        [ 'admin', "SELECT id, AES_DECRYPT(passwd,?) AS pass FROM admin WHERE BINARY login=? LIMIT 1" ],
    ){
        my %p = Db->line($h->[1], $cfg::Passwd_Key, ses::input('_uu'));
        Db->ok or Error($lang::err_try_again);
        if( %p )
        {
            my $hash = Digest::MD5->new;
            $hash = $hash->add($salt.' '.$p{pass});
            $hash = $hash->hexdigest;
            if( ses::input('_hash') ne $hash )
            {
                debug("Неупешная авторизация: `".ses::input('_hash')."` <> `$hash`");
                last;
            }
            my $ses = md5_base64(rand 10**10);
            $ses =~ tr/+/!/;
            debug("Авторизация успешна. Создал сессию `$ses`, записываю в cookie: `$cfg::cookie_name_for_ses`");
            my $rows = Db->do(
                "INSERT INTO websessions SET trust=1, ses=?, expire=unix_timestamp()+?, uid=?, role=?",
                $ses, $cfg::web_session_ttl,  $p{id}, $h->[0]
            );
            $rows>0 or Error('Temporary error');
            $ses::set_cookie->{$cfg::cookie_name_for_ses} = $ses;
            url->redirect( %{$ses::data->{__auth__}{url_param}} );
        }
    }
    ToLog("! $ses::ip. Неудачная попытка залогиниться под логином: ".ses::input('_uu'));
    ErrorMess('Неверный логин или пароль'.(ses::input('_hash') eq 'error' && '. Включите javascript в браузере!'));
}

my($F);
if( ref $ses::data->{__auth__} && ref $ses::data->{__auth__}{url_param} )
{   # только  что была неудачная авторизация и есть ссылка на страницу, которая была до авторизации
    $F = $ses::data->{__auth__}{url_param};
}
 elsif( ses::input('a') =~ /^(login|logout|)$/ )
{
    $F = { a=>'' };
}
 else
{
    $F = $ses::input_orig;
}
my $salt = md5_base64(rand 10**10);
$salt =~ tr/+/!/;

my $unikey = Save_webses_data( module=>'login', data=>{ __auth__ => { salt=>$salt, url_param=>$F } } );

Show( url->form(
    -base => '?',
    -onsubmit => 'login_submit()',
    _unikey => $unikey,
    _salt   => $salt,
    _hash   => 'error',
    tmpl( 'box',
        css_class => 'boxpddng',
        title => 'Авторизация',
        msg => tmpl( 'login',
            mLogin_title => $cfg::net_title,
            mLogin_button => v::submit($lang::btn_enter),
        )
    )
));


Doc->template('base')->{document_ready} .= " login_start();";

$ses::set_cookie->{$cfg::cookie_name_for_ses} = undef;

Exit();

1;

