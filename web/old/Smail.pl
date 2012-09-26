#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
sub go
{
 !$mail_enable && &Error($V? "$V Управление почтой отключено в настройках биллинговой системы." : "Раздел недоступен.",$EOUT);
 $Adm->{id} && !$PR{93} && &Error("У вас нет прав на работу с почтовыми ящиками клиентов.",$EOUT);
 $dbh2=DBI->connect("DBI:mysql:database=$mail_db;host=$mail_host;mysql_connect_timeout=3",$mail_user,$mail_pass);
 
 $dbh2 or &Error($V? "$V Ошибка соединения с почтовой базой данных." : "Раздел управления почтой временно недоступен.",$EOUT);
 &SetCharSet($dbh2);
 if ($F{save})
   {
    for $i (0..100)
      {
       last unless defined($F{"m_email$i"});
       $m_email=&Filtr_mysql($F{"m_email$i"});
       next unless $m_email;
       $newpass=&Filtr_mysql($F{"m_pass$i"});
       # Учитываем, что клиент может попытаться подделать названия ящиков! Поэтому обязательно в запрос влючаем id
       &sql_do($dbh2,"UPDATE `$mail_table` SET `$mail_p_pass`='$newpass' WHERE `$mail_p_user`='$Mid' AND `$mail_p_email`='$m_email' LIMIT 1");
      }
    &OkMess(&bold("Изменения почтовых ящиков сохранены."));
    return;
   }

 $can_have_mail=$Plan_flags[$paket]=~/d/ && " Ваш тарифный пакет не предусматривает предоставление почтовых ящиков";
 $i=0;
 $out='';
 $sth=&sql($dbh2,"SELECT * FROM `$mail_table` WHERE `$mail_p_user`='$Mid'");
 while ($h=$sth->fetchrow_hashref)
   {
    $m_email=v::filtr($h->{"$mail_p_email"});
    $m_pass=v::filtr($h->{"$mail_p_pass"});
    $m_enable=$h->{"$mail_p_enable"}==1? "<span class=data1>Включен</span>" : "<span class=error>Заблокирован</span>.$can_have_mail";
    $out.=&RRow('*','lll',$m_email.v::input_h("m_email$i",$m_email),v::input_t("m_pass$i",$m_pass,32,32),$m_enable);
    $i++;
   }

 $out or &Error($can_have_mail || "У вас нет почтовых ящиков. Отправьте администрации заказ на создание почтового ящика",$EOUT);

 &OkMess(
   &form('!'=>1,'save'=>'me','Почтовые ящики:'.$br2.
     &Table('tbg1i',&RRow('head','ccc','Название ящика','Пароль','Состояние').$out).
     &submit_a('Сохранить изменения')
   )
 );
}

1;      
