#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

# если кофиг поврежден и нет пути к css, то возьмем с офсайта
$cfg::img_url = 'http://l3.dp.ua/i' if !$cfg::img_dir;
$Url = url->new( -base => 'https://'.$ses::server.$ses::script );

if( $F{_sadmin} ne $cfg::sadmin )
{
    Doc->template('base')->{main_v_align} = 'middle';
    Show $Url->form(
        Center(
            _('[p]','Service is temporarily unavailable').
            _('[p]','Enter system password: '.v::input_t(name=>'_sadmin').' '.submit('OK'))
        )
    );
    Exit();
}

$ses::debug = 1;

$Adm->{id} = 0;
$Adm->{trusted} = 1;
$Adm->{info_line} = "System login admin (ip=$ses::ip).";
$Adm->{pr} = {
    SuperAdmin      => 1,
    RealSuperAdmin  => 1,
    edt_main_tunes  => 1,
    edt_adm         => 1,
    2   => 1,
    3   => 1,
};

debug('pre',map{ $_, "\n",`$_`, "\n" }('ps ax | grep mysql','df -H'));

$F{a} = 'tune' if $F{a} !~ /^(oper|admin)$/;

$Url->{_sadmin} = $F{_sadmin};
$Url->{a} = $F{a};

$scrpt .= "&amp;_sadmin=$F{_sadmin}";

require "$F{a}.pl";

Db->new(
    host    => $cfg::db_server,
    user    => $cfg::user,
    pass    => $cfg::pw,
    db      => $cfg::db_name,
    timeout => $cfg::db_conn_timeout,
    tries   => 1,
    global  => 1,
);

my $msg = _('[li]', Db->is_connected? 'Соединение с БД есть' : 'Нет соединения с БД');
$msg .= _('[li]', 'Есть администратор с суперпривилегиями') 
    if Db->is_connected && Db->select_line("SELECT admin FROM admin WHERE privil LIKE '%,5,%' LIMIT 1");
$msg = _('[ul]',$msg);

ToLeft MessageBox($msg).Doc->template('base')->{left_block};

1;      
