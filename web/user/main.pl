#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use web::Data;

sub go
{
 my($Url,$usr) = @_;
 my $uid = $usr->{id};

 my $out = '';

 # --- Услуги ---

 my $db = Db->sql(
    "SELECT v.*, s.title AS next_title, s.price AS next_price ".
    "FROM v_services v LEFT JOIN services s ON v.next_service_id = s.service_id ".
    "WHERE v.uid=?", $uid
 );
 while( my %p = $db->line )
 {
    my $msg = _($lang::sMain_your_service, the_short_time($p{tm_start},1), $p{title});
    $msg .= _(':[commas|p]', $p{description}) if $p{description};
    my $time_left = $p{tm_end} - $ses::t;
    if( $time_left>0 )
    {
        # Если услуга заканчивается в течение суток - красным цветом
        my $time_left_css_cls = $time_left < 24*3600? 'error' : '';
        $msg .= _('[p]',
            _("Заканчивается через [span $time_left_css_cls] ([])", the_hh_mm($time_left), the_short_time($p{tm_end},1))
        );
    }
    if( $p{next_service_id} )
    {
        my $msg2 = $p{next_service_id} == $p{service_id} ? 'После завершения будет подключена эта же услуга.' :
            _('После завершения будет подключена услуга [filtr|bold|commas].', $p{next_title});
        if( $p{next_price} > 0 )
        {
            $msg2 .= _(' Стоимость [bold] [].', $p{next_price}, $cfg::gr);
            $msg .= _('[p]', $msg2.' Проверьте, что на вашем счете будет достаточно финансов для ее подключения');
        }
         elsif( $p{next_price} < 0 )
        {
            $msg .= _('[p]', _(' Ваш счет будет пополнен на [bold] []', -$p{next_price}, $cfg::gr));
        }
    }
    $out .= _('[li]', $msg);
 }

 # --- Сообщения, по умолчанию не старше 15 суток ---

 my $limit_time = $ses::t - 3600*24*($cfg::msg_to_usr_days_show||15);
 # 480 - Сообщение клиенту
 # 481 - Сообщение клиенту, клиент ознакомлен
 my $db = Db->sql(
    "SELECT * FROM pays WHERE mid=? AND category IN (480,481) AND time>? ORDER BY time DESC LIMIT 3",
    $uid, $limit_time,
 );
 my $count_msg = 0;
 while( my %p = $db->line )
 {
    # не выводим 2-е и 3-е сообщение если клиент уже нажимал `ознакомлен`
    ++$count_msg > 1 && $p{category}==481 && next;
    my $comment = $p{comment};
    $comment eq '' && next;

    my $time = the_short_time($p{time},1);
    $comment =~ s/\n/<br>/g;
    my $msg = _($lang::smain_msg_from_adm, $time, $comment);
    if( $p{category}==480 )
    {
        my $domid = v::get_uniq_id();
        $msg .= v::tag('div', id=>$domid, class=>'h_center', -body=>
            [ $Url->a($lang::sMain_msg_accepted, a=>'u_ajAcceptMsg', id=>$p{id}, domid=>$domid, -ajax=>1, -class=>'nav') ]
        );
    }
    $out .= _('[li]', $msg);
 }


 # --- Временные платежи ---
 my %p = Db->line("SELECT cash, time FROM pays WHERE mid=? AND category=3 LIMIT 1", $uid);
 if( %p )
 {
    # Если подключен плагин u_pays, то выведем ссылку `см. платежи`
    $out .= _('[li]',
        _( $lang::smain_tmp_pay,
            $p{cash}, $cfg::gr, the_time($p{time}),
            $cfg::plugins->{u_pays}? $Url->a($lang::smain_see_pays, a=>'u_pays') : ''
        )
    );
 }


 # --- Последний платеж ---
 
 my %p = Db->line("SELECT time,cash FROM pays WHERE mid=? AND cash<>0 AND time>? ORDER BY time DESC LIMIT 1", $uid, $limit_time);
 if( %p && $p{cash} != 0)
 {
    my $msg = _($p{cash}<0? $lang::smain_negative_pay : $lang::smain_positive_pay, the_time($p{time}), $p{cash}, $cfg::gr);
    $msg .= _('[p]', $Url->a($lang::smain_see_pays, a=>'u_pays')) if $cfg::plugins->{u_pays};
    $out .= _('[li]', $msg);
 }

 $out && Show MessageWideBox( _('[ul]',$out) );

 my $balance_css_cls = $usr->{balance}<0? 'error' : 'bold';
 my @right = ();
 push @right, _("[] [span $balance_css_cls] []", $lang::sMain_balance_is, $usr->{balance}, $cfg::gr);

 my $tbl = tbl->new( -class=>'td_medium td_wide' );

 $tbl->add('', 'll', $lang::lbl_login, $usr->{name});
 $tbl->add('', 'll', $lang::lbl_fio,   $usr->{fio});

 my $fields = Data->get_fields($uid);
 foreach my $fid( sort{ $fields->{$a}{order} <=> $fields->{$b}{order} } keys %$fields )
 {
    $fields->{$fid}{name} =~ /^_adr_/ or next;
    my $value = $fields->{$fid}->show( cmd=>'show' );
    $value eq '' && next;
    $tbl->add('', 'll', $fields->{$fid}{title}, [$value]);
 }

 Show WideBox( msg => $tbl->show, title => $lang::sMain_private_data );

 $cfg::Show_PPC && push @right, _($lang::smain_your_PPC_is, Make_PPC($uid));
 ToRight MessageWideBox( '<p>'.join('</p><p>', @right).'</p>' );

}

1;
