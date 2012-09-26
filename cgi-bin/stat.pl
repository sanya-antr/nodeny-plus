#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

$cfg::main_config = '/usr/local/nodeny/sat.cfg';

# Не устанавливать!! Debug будет выводиться в браузер до авторизации
$ses::debug = 0;

$ses::debug_log = '/tmp/nodeny_' . time() . '_' . int(rand 5**10) . '.log';

$cfg::dir_home = $cfg::main_config;
$cfg::dir_home =~ s|/[^/]+$||;
$cfg::dir_web  = $cfg::dir_home.'/web';

unshift @INC, $cfg::dir_home;

$ses::ajax = $ENV{HTTP_X_REQUESTED_WITH} eq 'XMLHttpRequest';

$SIG{'__DIE__'} = sub {
    die @_ if $^S; # die внутри eval{ }, не eval "code"
    eval{ Hard_exit(@_) };
    _hard_exit_html('very hard error');
};

sub _hard_exit_ajax
{
    my($err) = @_;
    eval 'use JSON';
    if( $@ )
    {   # use не выполнится, если сюда попали по die при require/use
        $err = $ses::debug? $err."\n\n".$@ : 'Hard Error. Need debug mode';
    }
     else
    {
        my $json = [];
        if( $ses::debug )
        {
            debug('error', $err);
            push @$json, { id=>'debug', data=>Debug->show, action=>'insert' };
        }
        push @$json, { type=>'js', data=>"console.log('internal error. Turn debug on')" };
        $err = to_json($json);
    }
    print "Content-type: text/html; charset=utf-8\n\n".$err;
    exit;
}
sub _hard_exit_html
{
    print "Content-type: text/html\n\n";
    print "<html><head><meta http-equiv='Content-Type' content='text/html; charset=utf-8'></head>".
            "<body style='margin-top:10%; text-align:center'>".$_[0]."</body></html>";
    exit;
}
sub Hard_exit
{
    my $err = join ' ', @_;
    $ses::ajax && _hard_exit_ajax($err);
    if( $ses::debug )
    {   # у админа есть право просматривать debug, выведем в браузер
        eval{
            debug('error', $err);
            $err = Debug->show;
        };
        $err .= '<br><br>'.$@ if $@;
        $ses::calls_pm_is_loaded && eval{
            # очистим основное окно
            Doc->template('base')->{main_block} = '';
            ErrorMess($err);
            # очистим debug т.к. он уже выведен в окно с ошибкой
            Debug->flush;
            Exit();
        };
        # здесь либо ошибка в eval{} либо calls.pm еще не загружен
        _hard_exit_html($err);
    }
    # откроем на запись чтоб быть уверенным, что модуль Debug сможет записать
    open(F, ">>$ses::debug_log") or _hard_exit_html("Cannot save to $ses::debug_log");
    eval { 
        debug($err);
        Debug->param( -type=>'file', -file=>$ses::debug_log, -nochain=>0 );
        Debug->show; # весь накопленный debug выводим в файл
    };
    if( $@ )
    {   # не удалось записать через Debug, запишем сами (будет менее информативно)
        my @info = caller(0);
        print F "\n--- $info[1] line $info[2] ---\n$err";
    }
    $ses::calls_pm_is_loaded && eval{
        Doc->template('base')->{main_block} = '';
        Error($cfg::critical_error_msg || "Код ошибки: $ses::debug_log");
    };
    _hard_exit_html($cfg::critical_error_msg || "Temporary error<br>cat $ses::debug_log");
}

eval "use Debug";
eval "use web::calls";

$ses::calls_pm_is_loaded = 1;

Db->is_connected or die 'No DB connection';

if( !$ses::auth->{auth} )
{
    if( $ses::ajax )
    {
        ajModal_window('Необходимо залогинится');
        Exit();
    }
    debug('Не авторизован - загружаем login.pl');
    Require_web_mod('login');
    Exit();
}
if( ses::input('a') eq 'logout' )
{
    debug('Команда разлогиниться');
    remove_session();
}

# Загрузим реестр плагинов
my $plg_reestr_file = "$cfg::dir_home/cfg/web_plugins.list";
open(F,"<$plg_reestr_file") or die _($lang::cannot_load_file, $plg_reestr_file);
$cfg::plugins = {};
my($cod_prefix, $dir_prefix) = ('', '');
while( <F> )
{
    chomp;
    # комментарий либо пустая строка
    /^\s*#/ && next;
    /^\s*$/ && next; 
    if( /^\s*\[(.+):(.+)\]/ )
    {
        $cod_prefix = $1.'_';
        $dir_prefix = $2.'/';
        next;
    }
    my($cod, $for_adm, $ajax, $file, $descr) = split /\s+/, $_, 5;
    $cod  = $cod_prefix.$cod;
    $file = $dir_prefix.$file;
    $cfg::plugins->{$cod} = { for_adm=>$for_adm, ajax=>$ajax, descr=>$descr, file=>$file };
}
close(F);

my $start_mod = $ses::auth->{role} eq 'user'? 'start_user' : 'start_admin';
my $err = Require_web_mod($start_mod);
$err && die $err;

Exit();

# -- в этом месте будет дописана подпрограмма get_main_config --

