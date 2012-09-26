#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use vars qw( %F $Url %U );

sub go
{
 my $uid = $U{id};
 my $not_allowed = 0;
 # Отправка сообщений заблокирована администрацией?
 my %p = Db->line("SELECT comment FROM pays WHERE mid=? AND category=451 LIMIT 1", $uid);
 if( %p )
 {
    ToTop _($lang::smsadm_msg_not_allowed, $p{comment});
    $not_allowed++;
 }

 # Количество сообщений за последние сутки от клиента, на которые администрация не дала ответ
 # принимаем во внимание только неотвеченные вопросы
 my %p = Db->line("SELECT COUNT(*) AS n FROM pays WHERE mid=? AND category=491 AND time>(unix_timestamp()-24*3600)", $uid);
 my $count_mess = %p? $p{n} : 0;
 if( $count_mess>0 )
 {
    my $msg = ($lang::smsadm_1_msg,$lang::smsadm_2_msg,$lang::smsadm_3_msg,$lang::smsadm_4_msg)[$count_mess-1] || "$count_mess $lang::smsadm_x_msg";
    ToRight MessageBox( _($lang::smsadm_sent_count, $msg) );
 }
 if( $count_mess >= $cfg::mess_max_times )
 {
    ToTop _($lang::smsadm_n_msg_allowed, $cfg::mess_max_times);
    $not_allowed++;
 }

 my $mess = $F{mess};
 # разрешим то, что можно, остальное запретим
 $mess =~ s/[^A-Za-z0-9А-Яа-яёЁіІїЇєЄ().,+=!?:;*_№&#'"`\-\s\@\$\/\^\[\]\|\\	]//g;
 $mess =~ s/\r//g;

 if( length($mess)>1500 )
 {
    ToTop $lang::smsadm_long_mess_1;
    show_input_msg($mess,$not_allowed);
    return;
 } 

 if( !$mess || $not_allowed )
 {  # не eq '' - посылка одного нуля нам не нужна
    show_input_msg('',$not_allowed);
    return;
 }

 $mess =~ s/([^\s]{64})/$1\n/g; # последовательности символов длиной больше 64 разорвем переводом строки
 $mess =~ s/( *\n){3,}/\n\n/g;  # больше двух подряд идущих переводов строк заменяем на 2 перевода строки

 Pay_to_DB(uid=>$uid, category=>491, reason=>$mess)>0 or Error($lang::statpl_critical_error);
 my $pay_id = Db::result->insertid || Error($lang::statpl_critical_error);

 my $url = url->new( -base => 'https://'.$ses::server.$cfg::Script_adm );
 my $email = _( $lang::smsadm_email_tmpl,
    $mess,
    url->url( a=>'pays', q=>$pay_id, mid=>$uid),
    url->url( a=>'user', id=>$uid),
 );
 my $grp = $U{grp};
 # Отправим сообщение на email-ы администраторов, учитывая допуск к группе
 my $db = Db->sql(
    "SELECT grp_admins,grp_admins2 FROM user_grp WHERE grp_id=?",
    $grp,
 );
 while( my %p = $db->line )
 {
    my $grp_admins = $p{grp_admins};
    my $grp_admins2 = $p{grp_admins2};
    my $db = Db->sql(
        "SELECT id,email FROM admin WHERE email LIKE '%@%' AND (email_grp LIKE ? OR email_grp LIKE ? OR email_grp LIKE ?) OR email_grp=?",
        "$grp,%" ,"%,$grp,%", "%,$grp", $grp,
    );
    while( my %p = $db->line )
    {
       my $aid = $p{id};
       next if $grp_admins!~/,$aid,/ || $grp_admins2!~/,$aid,/;
       Smtp($email, $p{email});
    }
 }

 $Url->redirect( -made => $lang::smsadm_sent );
}

sub show_input_msg
{
 my($msg,$not_allowed) = @_;
 my $uid = $U{id};
 if( !$not_allowed )
 {
    Show MessageWideBox(
        $Url->form(
            Center( $lang::smsadm_msg_to_adm ).
            Center( v::input_ta('mess',$msg,60,10) ).
            Center( v::submit($lang::smsadm_send, 'padding') )
        )
    );
 }
 
 my $tbl = tbl->new( -class=>'width100 td_tall td_wide' );
 my $sql = "SELECT * FROM pays WHERE mid=$uid AND category IN(490,491,492,493) ORDER BY time DESC";
 my($sql,$page_buttons,undef,$db) = Show_navigate_list($sql,$F{start},10,$Url);
 while( my %p = $db->line )
 {
    # 490 - Сообщение клиенту
    # 493 - Сообщение клиенту, клиент ознакомлен
    my $to_usr = $p{category}==490 || $p{category}==493;
    my $reason = $p{reason};
    my $msg = '';
    if( $to_usr && $reason =~ /^\d+$/ )
    {   # сообщение клиенту и в поле reason число - id цитируемой записи
        my %h = Db->line("SELECT reason FROM pays WHERE id=? AND mid=? AND category IN(491,492)", $reason, $uid);
        $msg .= _($lang::smsadm_your_msg_quote,$h{reason}) if %h;
    }
    $msg .= $to_usr? $p{comment} : _('[div disabled]',v::filtr($reason));
    $msg eq '' && next;
    my $from = $to_usr? v::bold($lang::smsadm_from_adm) : $lang::smsadm_from_u;
    my $url = !!Adm->id && url->a($lang::smsadm_btn_more, a=>'pays', act=>'show', id=>$p{id});
    my $time = the_short_time($p{time},1);
    $tbl->add('*', 'lllc', [$time], [$from], [$msg], [$url]);
 }
 !$tbl->{data} && !$page_buttons && return;
 $tbl->ins('head','llll',$lang::lbl_time,$lang::lbl_author,$lang::lbl_msg,'');
 $tbl->ins('',4,[$page_buttons]) if $page_buttons;
 $tbl->add('',4,[$page_buttons]) if $page_buttons;

 Show MessageWideBox( $tbl->show );
}



1;      
