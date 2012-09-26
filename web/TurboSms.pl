#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
 my($Url) = @_;
 Adm->chk_privil_or_die('SuperAdmin');

 my $db_table = $cfg::turbosms_db_login;
 ( !$cfg::turbosms_db_pass || $db_table =~ /[`"'\\]/ ) && Error('Плагин TurboSms не сконфигурирован');

 my $sms_db = Db->new(
    host    => $cfg::turbosms_db_server,
    user    => $cfg::turbosms_db_login,
    pass    => $cfg::turbosms_db_pass,
    db      => $cfg::turbosms_db_database,
    timeout => 3,
    tries   => 2,
    global  => 0,
 );

 $sms_db->connect;
 $sms_db->is_connected or Error('Нет соединения с БД TurboSms');

 my $Fstart = ses::input_int('start');

 my $cur_module = ses::cur_module;

 my $sql = "SELECT * FROM $db_table ORDER BY id DESC";
 my($sql, $page_buttons, $rows, $db) = Show_navigate_list($sql, $Fstart, 22, $Url, $sms_db);

 my $tbl = tbl->new( -class=>'td_wide td_medium fade_border pretty' );

 while( my %p = $db->line )
 {
    my $link = [ url->a($p{number}, a=>'users', m_d_adr_telefon=>1, f_d_adr_telefon=>substr($p{number},-7,7)) ];
    $tbl->add('*',[
        [ '',       'Телефон',          $link           ],
        [ '',       'Сообщение',        $p{message}     ],
        [ 'h_right','Стоимость, крд.',  $p{cost}        ],
        [ '',       'Время отправки',   $p{sended}      ],
        [ '',       'Статус',           $p{status}      ],
        [ '',       'Статус код',       $p{dlr_status}  ],
    ]);
 }

 Show Center( $page_buttons.$tbl->show.$page_buttons );
}

1;
