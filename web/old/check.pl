#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$Adm->{pr}{show_fio} or Error('Доступ запрещен. Недостаточно привилегий.');
$Adm->{trusted} or Error('Не разрешен доступ, поскольку при авторизации вы не указали, что работаете за доверенным компьютером.');

if( !$F{act} )
{
   $OUT.=&MessX('Запущена проверка системы, это займет некоторое время',1,0);
   $DOC->{base}{head_tag} .= qq{<meta http-equiv="refresh" content="0; url='$scrpt&act=check_now'">};
   &Exit;
}


# проверка версий таблиц
# ...

LoadMoneyMod();

$out='';
if( $Adm->{pr}{SuperAdmin} )
{  # суперадмин. Проверим, что есть доступ ко всем группам
   $out.=!$Adm->{grp_lvl}{$_} && &commas($UGrp_name{$_}).',' foreach (keys %UGrp_name);
   $out="Вы суперадминистратор, но не имеете доступ к группам: $out ".
      "поэтому клиенты в этих группах не будут проверены. Это не критическая ошибка.".$br2 if $out; # запятую перед 'поэтому' не ставь т.к. она будет:)
}else
{
   $OUT.=$br.&MessX('Результаты проверки системы. Внимание, проверяются только те компоненты системы и группы клиентов, к которым вы имеете доступ.');
}

$out1=$out2=$out3='';

my $Allow_grp = join ',',keys %{$Adm->{grp_lvl}};
$where=!$Adm->{pr}{SuperAdmin} && "u.grp IN ($Allow_grp) AND"; # для суперадмина не делать фильтр по группе т.к нужно вычислить клиентов в несуществующих группах
$sth=&sql($dbh,"SELECT u.*,SUM(cash) AS cash FROM users u LEFT JOIN pays p ON u.id=p.mid ".
  "WHERE $where (p.type IN (10,20) OR p.type IS NULL) GROUP BY u.id ORDER BY u.mid,u.sortip");
while ($p=$sth->fetchrow_hashref)
  {
   next if $p->{balance}==$p->{cash};
   $out1.='<li>'.&ShowClient($p->{id},$p->{name},'')." - баланс учетной записи ($p->{balance} $gr) ".
     "не сходится с суммой всех проведенных платежей ($p->{cash} $gr). ".
     "Требуется ручная корректировка баланса.</li>";
  }

%grps=%pakets=();
# ORDER BY mid обязателен
$sth=&sql($dbh,"SELECT * FROM users ".(!$Adm->{pr}{SuperAdmin} && "WHERE grp IN ($Allow_grp)")." ORDER BY mid,sortip");
while ($p=$sth->fetchrow_hashref)
  {
   ($id,$mid,$name,$ip,$sortip,$grp,$paket,$state,$balance)=&Get_fields qw(
     id  mid  name  ip  sortip  grp  paket  state  balance );
   $grps{$id}=$grp;
   $pakets{$id}=$paket;
   $client=&ShowClient($id,$name,'');
   $out3.="<li>$client доступ не заблокирован, а пакет ".&commas($Plan::main->{$paket}{name_short})." указывает заблокировать.</li>" if $Plan_flags[$paket]=~/k/ && ($state ne 'off');

   if ($ip!~/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ || $1>255 || $2>255 || $3>255 || $4>255)
   {
      $out1.="<li>$client - некорректный ip: ".&commas(&Filtr_out($ip)).'</li>';
   }
    else
   {
      $good_sortip=$2*65536 + $3*256 + $4;
      if ($good_sortip!=$sortip)
      {
         $rows=&sql_do($dbh,"UPDATE users SET sortip=$good_sortip WHERE id=$id LIMIT 1");
         $out3.="<li>$client - некорректный id сортировки (поле sortip). ".($rows==1? 'Исправлено.':&bold('Не исправлено.')).'</li>';
      }
   }

   if (!$mid)
   {  # основная запись
      $out1.="<li>$client в несуществующей группе № $grp</li>" if !$UGrp_name{$grp} && $Adm->{pr}{SuperAdmin};
   }
    else
   {  # алиасная запись
      if ($grp!=$grps{$mid})
      {
         $out2.="<li>$client - алиаснная запись, номер группы не совпадает с основной. Был $grp, устанавливаю в $grps{$mid}</li>";
         &sql_do($dbh,"UPDATE users SET grp=$grps{$mid} WHERE id=$id LIMIT 1");
      }
      if ($paket!=$pakets{$mid})
      {
         $out2.="<li>$client - алиаснная запись, пакет не совпадает с номером пакета основной записи. Был $paket, устанавливаю в $pakets{$mid}</li>";
         &sql_do($dbh,"UPDATE users SET paket=$pakets{$mid} WHERE id=$id LIMIT 1");
      }
      if ($balance!=0)
      {
         $out2.="<li>$client - алиаснная запись имеет баланс не равный нулю, баланс должнен быть только на основной записи. Баланс алиасной записи обнулен.</li>";
         &sql_do($dbh,"UPDATE users SET balance=0 WHERE id=$id AND mid=$mid LIMIT 1",'Обнуляем баланс алиасной записи');
      }
   }

   if ($mid && $cash!=0)
   {  # правда не отловится ситуация когда сумма платежей = 0, но это редкая ситуация
      $out1.="<li>$client - алиасная запись и на ней числятся платежи. Платежи необходимо перенести на основную запись.</li>";
   }
  }

sub check_tarif
{
 ($f,$sql,$h)=@_;
 $sth=&sql($dbh,"SELECT u.id,u.name,u.$f FROM users u LEFT JOIN plans2 p ON u.$f=p.id WHERE u.mid=0 AND u.grp IN ($Allow_grp) AND $sql (p.name='' OR p.id IS NULL)",
   'Есть клиенты на несуществующих тарифах и на тарифах без названия?');
 $out1.='<li>'.&ShowClient($p->{id},$p->{name},'')." - несуществующий $h № ".$p->{$f}.'</li>' while ($p=$sth->fetchrow_hashref);
}

&check_tarif('paket','','пакет');
&check_tarif('next_paket','u.next_paket<>0 AND','заказанный пакет');

{
 last unless $Adm->{pr}{SuperAdmin};
 $out4='';
 $i=0;
 $sth=&sql($dbh,"SELECT * FROM users_trf WHERE uid NOT IN (SELECT id FROM users)",'в таблице users_trf есть записи-сироты?');
 while ($p=$sth->fetchrow_hashref)
 {
    $h='id='.$p->{uid}.
       ", in1=$p->{in1} out1=$p->{out1}".
       ", in2=$p->{in2} out2=$p->{out2}".
       ", in3=$p->{in3} out3=$p->{out3}".
       ", in4=$p->{in4} out4=$p->{out4}";
    &ToLog("Бесхозная запись в таблице users_trf, $h");
    $out4.=$h.$br;
    $i++;
 } 
 if ($i)
 {
    $limit=50;
    if ($i<=$limit)
    {
       $rows=&sql_do($dbh,"DELETE FROM users_trf WHERE uid NOT IN (SELECT id FROM users) LIMIT $limit");
       $out4.=&bold("Удалено $rows записей");
    }else
    {
       $out4.=&bold('Внимание! Оказалось, что записей слишком много. NoDeny требует от администратора провести анализ действительно ли эти записи '.
        'бесхозные либо это серьезный сбой базы данных. Вам необходимо взять несколько id перечисленных выше и получить по ним информацию, каким клиентам они '.
        'принадлежат. Если ни по одному не будет получена информация, т.е это действительно записи-сироты, выполните sql-запрос:<br><br>'.
        "DELETE FROM users_trf WHERE uid NOT IN (SELECT id FROM users)");
    }
    $out1.="<li>В таблице users_trf присутствуют записи, которые не ассоциированы ни с каким клиентом. Вероятно они появились в результате ".
      "некорректного удаления клиентов, т.е не средствами админки NoDeny. Эти бесхозные записи надо удалить чтобы агенты доступа не считали ".
      "эти записи существующими и не открывали к ним трафик от других клиентов. Большая часть информации в этой таблице не ключевая и может быть ".
      "удалена, однако кроме всего таблица хранит реальный трафик клиента за текущий месяц. На всякий случай трафик будет сохранен в логах, чтобы ".
      "в будущем была возможность отката. Список id записей:$br2$out4</li>";
 }

 @f=(
    "Количество записей в таблице платежей (pays), которые связаны с отсутствующими в БД клиентами",
    "FROM pays p LEFT JOIN users u ON u.id=p.mid WHERE u.grp IS NULL and p.mid>0",'p.*',
    "Поле mid указывает на отсутствующую клиентскую запись. Если type равен 10 и при этом bonus='', то платеж финансовый - ".
      "удаление платежа повлияет на наличность 'на руках' у администратора admin_id.",

    "Количество записей в таблице платежей (pays), которые связаны с отсутствующими в БД работниками",
    "FROM pays p LEFT JOIN j_workers w ON p.mid=-w.worker WHERE w.office IS NULL and p.mid<0",'p.*',
    "Поле mid без знака указывает на отсутствующую запись работника в таблице j_workers. Удаление платежа повлияет на наличность 'на руках' у администратора admin_id.",

    "Количество записей типа 'передача наличных' в таблице платежей (pays), которые связаны с отсутствующими в БД администраторами",
    "FROM pays p LEFT JOIN admin a ON p.reason=a.id WHERE p.type=40 AND a.office IS NULL",'p.*',
    "Поле reason указывает на отсутствующего администратора в таблице admin. Удаление платежа повлияет на наличность 'на руках' у администратора admin_id.",

    "Количество записей типа 'передача наличных' в таблице платежей (pays), которые связаны с отсутствующими в БД администраторами",
    "FROM pays p LEFT JOIN admin a ON p.coment=a.id WHERE p.type=40 AND a.office IS NULL",'p.*',
    "Поле coment указывает на отсутствующего администратора в таблице admin. Удаление платежа повлияет на наличность 'на руках' у администратора admin_id.",

    "Количество записей в таблице платежей (pays), автор которых отсутствует в таблице администраторов",
    "FROM pays p LEFT JOIN admin a ON p.admin_id=a.id WHERE p.admin_id<>0 AND a.office IS NULL",'p.*',
    "Поле admin_id указывает на отсутствующего администратора в таблице admin.",

    "Количество записей в таблице платежей (pays), в которых установлена денежная сумма, однако платежи не являются финансовыми (сообщения, события)",
    "FROM pays WHERE type NOT IN (10,20,40) AND cash<>0",'*',
    'Установка поля cash в 0 не повлияет на финансовые состояние клиента или администратора, осуществившего платеж. Однако постарайтесь разобраться почему произошла такая ситуация.',

    "Количество записей сообщений в таблице платежей (pays), в которых оба поля комментария пустые",
    "FROM pays WHERE type=30 AND reason='' AND coment=''",'*',
    'Можно смело удалять такие записи.',
 );

 $out4='';
 while ($mess=shift @f)
 {
    $sql=shift @f;
    $sql_fields=shift @f;
    $mess2=shift @f;
    $p=&sql_select_line($dbh,"SELECT COUNT(*) AS n $sql",$mess);
    $out4.="<li>$mess: ".&bold($p->{n}).". Список записей можете получить выполнив запрос:".$br.
      "SELECT $sql_fields $sql$br$mess2</li>" if $p && $p->{n}>0;
 }
 $out2.=$out4;

 $out4='';
 $sth=&sql($dbh,"SELECT p.id FROM plans2 p LEFT JOIN newuser_opt n ON p.newuser_opt=n.id WHERE p.name<>'' AND p.newuser_opt<>0 AND n.opt_name IS NULL",
   'Тарифы с несуществующими предустановленными подключениями');
 $out4.=&ahref("$scrpt0&a=tarif&act=show&id=$p->{id}",$p->{id}).', ' while ($p=$sth->fetchrow_hashref);
 $out2.="<li>Тарифы с несуществующими предустановленными подключениями: $out4</li>" if $out4;
} 

$out.=&div('message',$out1? "<span class=error>Серьезные проблемы:</span>$br2<ul>$out1</ul>" : 'Серьезных проблем нет.',1);
$out.=&div('message',$out2? &bold('Важные проблемы:').$br3."<ul>$out2</ul>" : 'Важных проблем нет.',1);
$out.=&div('message','Некритичные проблемы:'.$br3."<ul>$out3</ul>",1) if $out3;

$OUT.=&div('message lft',$out).$br;

# === Проверка карточек оплаты ===

&Exit;

1;
