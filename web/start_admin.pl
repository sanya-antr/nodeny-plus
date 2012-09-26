#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

my $aid = $ses::auth->{uid};

if( ! $ses::auth->{adm}{id} )
{
    debug('warn', "Несуществующий админ в таблице сессий: id=$aid");
    remove_session();
}

Adm->set_current( $ses::auth->{adm} );


my $login_chain = Adm->login;
my $info_line = "Adm. $login_chain (id=$aid, ip=$ses::ip).";

my $trusted = $ses::auth->{role} eq 'admin';
$ses::debug = 1 if Adm->chk_privil('SuperAdmin') && $trusted && $ses::cookie->{debug};

# --- Переключение на другого админа ---
{
    my $new_adm_id = int $ses::cookie->{new_admin} or last;
    Adm->chk_privil('SuperAdmin') or last;
    my %p = Db->line("SELECT * FROM admin WHERE id=?", $new_adm_id);
    %p or last;

    $info_line .= " turned into $p{login} (id=$p{id}).";
    $login_chain .= ' &rarr; '.$p{login};

    Adm->set_current( \%p );

    $aid = $new_adm_id;
}

Doc->template('top_block')->{pic} = 'title_left.gif';
Doc->template('top_block')->{login_chain} = $login_chain;
push @{$ses::subs->{exit}}, \&_show_top_block;

my $cmd = ses::input('a');
if( !$cfg::plugins->{$cmd} )
{
    $ses::ajax && Error("Неизвестная команда `$cmd`");
    $cmd && debug('warn', "Неизвестная команда `$cmd`");
    $cmd = 'main';
}

if( $cfg::plugins->{$cmd}{ajax} && !$ses::ajax )
{
    debug('warn', "Команда $cmd выполняется в ajax-контексте, но http-запрос не ajax - выводим титульную страницу");
    $cmd = 'main';
}

Adm->chk_privil(1) or Error_('Доступ в админку для логина [bold] заблокирован.', Adm->login);

my $plg = $cfg::plugins->{$cmd};
Doc->template('top_block')->{title} = $plg->{descr};

$ses::input->{a} = $cmd;
my $url = url->new( a=>$cmd );
my $mod = $plg->{for_adm}? $plg->{file} : 'start_user';

sub go{};
my $err = Require_web_mod($mod);
$err && die $err;
$plg->{for_adm} && go($url);

sub _show_top_block
{
    Doc->template('base')->{top_block} .= tmpl('adm_top_block', %{Doc->template('top_block')});
}

1;
