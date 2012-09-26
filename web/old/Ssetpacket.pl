#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
sub go
{
 $OUT.=$br;
 $go_main=$br2.&CenterA("$scrpt&a=101",'На главную &rarr;');

 $p=&sql_select_line($dbh,"SELECT mid FROM pays WHERE mid=$Mid AND type=50 AND category=450 LIMIT 1",'Заблокирован заказ/смена тарифного плана?');
 $p && &Error("Вам не разрешено изменять/заказывать автоматическую смену тарифного плана. Это может сделать только администрация.$go_main",$EOUT);

 $balance=$U{$Mid}{balance};
 $my_preset=$U{$Mid}{preset};
 $paket = $U{$Mid}{paket};
 $paket3 = $U{$Mid}{paket3};
 $next_paket = $U{$Mid}{next_paket};
 $next_paket3 = $U{$Mid}{next_paket3};
 $only_my_preset=$Plan_flags[$paket]=~/c/; # клиент может заказывать только пакеты, имеющие пресет текущего пакета ($my_preset)

 $Fpaket=int $F{paket};
 $act=int $F{act};
 $actd=int($act/10);

 {
  last if $actd!=1;
  # Допокупка пакета
  &SP_AddPaket;
  return;
 }

 $out1=&SP_Select("$scrpt&act=21",0);
 $out2=&SP_Select("$scrpt&act=31&balance=$balance",1); # сохраним баланс, чтобы регистрировать повторную допокупку в результате обновления страницы
 $out3=&SP_Select3("$scrpt&act=41",0);
 $out4=&SP_Select3("$scrpt&act=51&balance=$balance",1); 

 &Error('Нет тарифных планов, которые вы можете заказать через клиентскую статистику.',
        $EOUT) if !($out1 || $out2 || $out3 || $out4 || $next_paket || $next_paket3);

 {
  $act && last;
  $out=&div('big cntr','Выберите действие:').$br2.'<ul>';
  $out.='<li>На следующий месяц у вас заказана автоматическая смена тарифного плана на '.
    &bold($Plan_name_short[$next_paket]).'. '.&ahref("$scrpt&act=21&paket=0",'Отменить заказ тарифного плана').
    $br2.'</li>' if $next_paket;
  $out.='<li>На следующий месяц у вас заказана автоматическая смена тарифного плана на '.
    &bold($Plans3{$next_paket3}{name_short}).'. '.&ahref("$scrpt&act=41&paket=0",'Отменить заказ тарифного плана').
    $br2.'</li>' if $next_paket3;
  $out.='<li>'.&ahref("$scrpt&act=20",'Заказ тарифного плана на следующий месяц').$br2.'</li>' if $out1;
  $out.='<li>'.&ahref("$scrpt&act=30",'Изменение текущего тарифного плана').$br2.'</li>' if $out2;
  $out.='<li>'.&ahref("$scrpt&act=40",'Заказ дополнительного тарифного плана на следующий месяц').$br2.'</li>' if $out3;
  $out.='<li>'.&ahref("$scrpt&act=50",'Изменение текущего дополнительного тарифного плана').'</li>' if $out4;
  $out.='</ul>';
  $OUT.=&MessX($out,1);
  return;
 }

 {
  last if $actd!=2 && $actd!=4;
  $p=&sql_select_line($dbh,"SELECT COUNT(*) AS n FROM pays WHERE mid=$Mid AND type=50 AND category=428 AND time>($ut-3600*24)");
  $p && $p->{n}>=$Max_paket_sets && &Error('Вы превысили лимит заказов смены тарифного плана. '.
     "Не разшешается осуществлять заказ чаще $Max_paket_sets раз в 24 часа. Определитесь.",$EOUT);
 }

 &SP_SetNextPaket	if $actd==2;	# Заказ пакета на следующий месяц
 &SP_SetPaket		if $actd==3;	# Мгновенная смена пакета
 &SP_SetNextPaket3	if $actd==4;	# Заказ доп.пакета на следующий месяц
 &SP_SetPaket3		if $actd==5;	# Мгновенная смена доп.пакета
}

sub Check_Packet
{
 my $i=$_[0];
 $i or return(1);
 return(0) if $i>$m_tarif ||
   $i<0 ||
   !$Plan_name[$i] ||
   $Plan_flags[$i]!~/a/ ||
   ($only_my_preset && $my_preset!=$Plan_preset[$i]) ||
   $Plan_usr_grp[$i]!~/,$grp,/;
 $_[1] && !$Plan_price_change[$i] && return(0);
 return(1);
}


sub SP_AddPaket
{# --- Допокупка пакета ---
 $ErrMessP='Допокупка тарифного плана не может быть осуществлена';
 $act>10 && $F{balance}!=$balance && &Error("Обнаружено изменение вашего баланса. Возможно вы уже осуществили допокупку тарифного плана либо параллельно были проведены финансовые операции. Смотрите раздел ".&commas('платежи'),$EOUT);
 $Plan_flags[$paket]!~/m/ && &Error("$ErrMessP - в вашем тарифном плане это не предусмотрено.",$EOUT);
 $start_day && &Error($V? "$V $ErrMessP - день начала потребления услуг не равен нулю": $ErrMessP,$EOUT);
 $U{$Mid}{money_over} or &Error("$ErrMessP - у вас нет переработки в текущем тарифном плане. Возможно допокупка уже произведена.",$EOUT);

 $got_money=$Plan_price[$paket];

 {
  last if $act!=10;
  &SP_Select("$scrpt&act=11&balance=$balance",0,0); # сохраним баланс, чтобы регистрировать повторную допокупку в результате обновления страницы
  $out or &Error("Нет тарифных планов, которые вы можете докупить в текущем месяце.",$EOUT);
  $OUT.=&div('message lft',$br.'Разъяснение текущей ситуации:'.$br2.
    "На данный момент вы уже выработали предоплаченные пакетные мегабайты и стоимость ".
    "превышения трафика составляет ".&bold(sprintf("%.2f",$U{$Mid}{money_over}))." $gr ".
    "Расшифровку подсчета наличности вы можете увидеть ".&ahref("$scrpt&a=101",'на главной странице статистики').
    '. В дальнейшей работе, если вы будете потреблять трафик, то денежная переработка будет возрастать. '.
    'Администрация предоставляет вам возможность дозаказать дополнительный тарифный план до конца этого месяца. '.
    'При вашем согласии будет произведено следующее:'.$br2.
    &bold("<ul><li> В данный момент с вашего счета будет снята стоимость текущего тарифного плана: $got_money $gr, ".
    "т.е без переработки, указанной выше</li>".
    '<li> Потребленный вами трафик будет обнулен</li>'.
    '<li> Вы выберете тарифный план, который будет действовать до конца текущего месяца</li></ul>').$br2.
    'Обратите внимание: в этот месяц с вашего счета будет снятие за два пакета тарификации! Текущий и тот, который вы закажете. '.
    'Также, возможно, вам понадобится внести дополнительные средства в оплату докупаемого тарифного плана.'.$br2.
    &bold('После выбора тарифного плана в списке ниже, вы не сможете отменить проведенную операцию!').$br2.
    &CenterA("$scrpt&a=101",'ОТМЕНИТЬ').$br2
  ).$br2.$out;
  return;
 }

 (!$Fpaket || !&Check_Packet($Fpaket,0)) && &Error("Допокупка тарифного плана не выполнена - присланные вами данные неверны.",$EOUT);

 $coment="Внеплановое снятие за услуги доступа в интернет за пакет: ".($Plan_name_short[$paket]||"id=$paket")."\nТрафик:";

 $i=0;
 $reason="Трафик по направлениям. Вход-выход:\n";
 foreach $z ($Traf1,$Traf2,$Traf3,$Traf4)
 {
    ($t1,$t2)=($T[$i*2],$T[$i*2+1]); # входящий и исходящий трафик направления
    $i++;
    $coment.="\n$c[$i]: $z Мб" if ${"Plan_over$i"}[$paket]>0;
    ($t1+$t2) or next;
    ($t1,$t2)=(&split_n($t1),&split_n($t2));
    $reason.="$i: $t1 - $t2\n";
 }

 $coment.="\nПереработка трафика не засчитана.\nДопокупка пакета `$Plan_name_short[$Fpaket]`";

 $rows=&sql_do($dbh,"UPDATE users_trf SET in1=0,in2=0,in3=0,in4=0,out1=0,out2=0,out3=0,out4=0 WHERE uid=$Mid LIMIT 1");
 $rows<1 && &Error("Временная ошибка. Повторите запрос позже.$go_back",$EOUT);

 $rows=&sql_do($dbh,"INSERT INTO pays SET mid=$Mid,cash=-($got_money),type=10,bonus='y',admin_id=$Adm->{id},admin_ip=INET_ATON('$RealIp'),reason='$reason',coment='$coment',category=110,time=$ut");
 if ($rows<1)
 {
    &ToLog("!! При внеплановом снятии за услуги клиента id=$Mid произошла ошибка создания платежа-снятия, тем не менее текущий трафик обнулен.");
    &Error("Временная ошибка. Повторите запрос позже.$go_back",$EOUT);
 }

 $rows=&sql_do($dbh,"UPDATE users SET balance=balance-($got_money),paket=$Fpaket WHERE id=$Mid LIMIT 1");
 $rows<1 && &ToLog("!! После внепланового снятия за услуги произошла ошибка изменения баланса клиента id=$Mid. Уменьшите баланс на $got_money $gr");
 &sql_do($dbh,"UPDATE users SET paket=$Fpaket WHERE mid=$Mid LIMIT 1");

 &OkMess("Допокупка тарифного плана выполнена. С вашего счета снята стоимость предыдущего тарифного плана без учета переработки.",$EOUT);
}


# --- Смена пакета текущего месяца ---

sub SP_SetPaket
{
 {
  defined $F{paket} or last;
  $Plan_flags[$paket]=~/b/ && &Error('Ваш текущий тарифный план не позволяет самостоятельно менять его на иной. Это может сделать только администратор.',$EOUT);
  (!$Fpaket || !&Check_Packet($Fpaket,1)) && &Error('Смена тарифного плана не выполнена - присланные вами данные неверны.',$EOUT);
  $F{balance}!=$balance && &Error('Обнаружено изменение вашего баланса. Возможно вы уже сменили тарифный план либо параллельно были проведены финансовые операции. '.
     'Смотрите раздел '.&ahref("$scrpt&a=115",'платежи'),$EOUT);
  $Fpaket==$paket && &Error('Смена тарифного плана не выполнена - вы выбрали тот же тарифный план, который у вас в данный момент.'.$go_main,$EOUT);
  $got_money=$Plan_price_change[$Fpaket];
  $got_money>=$balance && &Error('На вашем балансе недостаточно средств для смены тарифного плана.',$EOUT);
  $coment="`$Plan_name_short[$paket]` на `$Plan_name_short[$Fpaket]`";
  $p_now=&commas($Plan_name_short[$paket]);
  $p_want=&commas($Plan_name_short[$Fpaket]);
  if( $act==31 )
  {
     &OkMess("<span class='big story'>&nbsp;&nbsp;<span class=error>Внимание!</span>. В данный момент вы обслуживаетесь на тарифном плане $p_now. ".
       "Вы решили изменить его на тариф $p_want стоимостью $Plan_price_change[$Fpaket] $gr Эта услуга платная, с вашего счета будет снято дополнительно ".
       &bold($got_money)." $gr".$br2.
       " После вашего согласия переключение будет произведено в течение нескольких минут, при этом сумма снятия будет посчитана так как будто вы ".
       "работаете на выбранном тарифном плане с начала месяца</span>.".$br3.
       &CenterA("$scrpt&act=32&balance=$balance&paket=$Fpaket",'Произвести смену тарифного плана').$br3.
       &CenterA($scrpt,'Отказаться'),$EOUT);
     return;
  }

  $coment="Смена тарифного плана $coment";
  $rows=&sql_do($dbh,"INSERT INTO pays SET mid=$Mid,cash=-($got_money),type=10,bonus='y',admin_id=$Adm->{id},admin_ip=INET_ATON('$RealIp'),coment='$coment',category=105,time=$ut");
  $rows<1 && &Error($V? "$V Ошибка создания платежа-снятия за смену тарифного плана" : "Временная ошибка. Повторите запрос позже.$go_back",$EOUT);

  $rows=&sql_do($dbh,"UPDATE users SET balance=balance-($got_money),paket=$Fpaket WHERE id=$Mid LIMIT 1");
  $rows<1 && &ToLog("!! После платной смены тарифного плана произошла ошибка изменения баланса клиента id=$Mid. Уменьшите баланс на $got_money $gr");

  &OkMess(&div('big',"Смена тарифного плана выполнена. С вашего счета снято $got_money $gr").$go_main,$EOUT);
  return;
 }

 $out2 or return;

 $OUT.=&MessX(&div('big','Смена тарифного плана в текущем месяце. Внимание! Операция платная.').$br2.
   'Ниже в списке выберите тарифный план, на который вы хотите изменить свой текущий. '.
   'После выбора, в этот же момент будет произведена замена вашего текущего тарифа на новый. Новый тарифный план '.
   'будет действовать как будто он был установлен с начала текущего месяца, т.е. деньги по старому тарифу '.
   'не будут сниматься с вашего счета.',1,1).$out2;
}



# --- Заказ пакета на следующий месяц ---

sub SP_SetNextPaket
{
 {
  defined($F{paket}) or last;
  $Plan_flags[$paket]=~/b/ && &Error('Ваш текущий тарифный план не позволяет самостоятельно менять его на иной. Это может сделать только администратор.',$EOUT);
  # установка пакета, $i - № пакета или 0 - `не менять`
  &Check_Packet($Fpaket,0) or &Error('Система взломана. Пароли высланы вам на email.',$EOUT);
  $Fpaket==$next_paket && &Error('Заказ тарифного плана не выполнен - вы выбрали тот же тарифный план, который уже заказан на следующий месяц.',$EOUT);

  &sql_do($dbh,"UPDATE users SET next_paket=$Fpaket WHERE id=$Mid LIMIT 1");
  Pay_to_DB(uid=>$Mid, type=>50, category=>428, reason=>$Fpaket? $Plan_name_short[$Fpaket] : '');

  OkMess($Fpaket? 'Заказ смены тарифного плана следующего месяца на '.&bold($Plan_name_short[$Fpaket]).' выполнен.'.$go_main :
     'Вы дали указание в следующем месяце не изменять ваш текущий тарифный план.',$EOUT);
  return;
 }
 
 $out1 or return;

 $OUT.=&MessX(&div('big cntr','Заказ тарифного плана на следующий месяц').$br2.
   "Ниже в списке выберите тарифный план, на который вас автоматически переключит система при наступлении следующего месяца.".$br2.
   "Под количеством предоплаченных мегабайт указано за какую составляющую трафика вы будете платить:".$br.
     &div('lft','<ul><li>входящий - вы платите только за полученные данные</li>'.
     '<li>исходящий - вы платите только за отправленные данные</li>'.
     '<li>сумма - вы платите за отправленные и полученные данные</li>'.
     '<li>наибольшая составляющая - вы платите за те данные, которые больше (либо за полученные либо за отправленные)</li></ul>'.
     'Если значение предоплаченных мегабайт имеет значение '.&commas('безлимитный').' - в данной категории количесто трафика неограничено.'
     ),1,1
   ).$out1;
}


sub SP_Select
{ 
 ($url,$only_now_change_pkt)=@_;
 # $only_now_change_pkt - показывать только те пакеты, на которые можно перейти в текущем месяце (имеют стоимость перехода)

 %pkts=();
 foreach $i (1..$m_tarif)
 {
    $pkts{$i}=$Plan_price[$i] if &Check_Packet($i,$only_now_change_pkt)
 }

 $out='';
 foreach $i (sort { $pkts{$a} <=> $pkts{$b} } keys %pkts)
 {# в порядке возрастания стоимости пакета
    $preset=$Plan_preset[$i];
    @c=('',&Get_Name_Class($preset));
    $out.=&RRow('head','lc','Тарифный план',&ahref("$url&paket=$i",$Plan_name_short[$i])).
          &RRow('*','lr',"Цена, $gr",&bold($Plan_price[$i]));
    $out.=&RRow('*','L',&Show_all($Plan_descr[$i])) if $Plan_descr[$i];
    $out.=&RRow('* error','lr',"Стоимость перехода на данный тарифный план, $gr",&bold($Plan_price_change[$i])) if $only_now_change_pkt;
    for $j (1..4)
    {
       $price_over_mb=${"Plan_over$j"}[$i];
       next if $j>1 && !$price_over_mb;
       $mb_in_paket= $Plan::main->{$i}{mb}{$j};
       $in_or_out_traf=&Get_name_traf(${"InOrOut$j"}[$i]);
       $out.=&RRow('*','lr',
          "$c[$j]) трафик. Предоплачено Мб<br>Оплачивается $in_or_out_traf",
          $mb_in_paket<$cfg::unlim_mb? $mb_in_paket : &bold('безлимитный')
       );
       $out.=&RRow('*','lr',"Цена превышения, $gr/Мб",$price_over_mb) if $mb_in_paket<$cfg::unlim_mb;
    }

    my $sum_mb += $Plan::main->{$i}{mb}{$_} foreach( 0..4 );
    if(($sum_mb + $Plan_over1[$i]+$Plan_over2[$i]+$Plan_over3[$i]+$Plan_over4[$i])==0)
    {
       $out.=&RRow('*','L',&bold('Услуги доступа в интернет не предоставляются'));
    }
     elsif ($Plan_over1[$i]==0)
    {
       $out.=&RRow('*','L','При превышении предоплаченного трафика '.&commas($c[1]).', доступ в интернет будет заблокирован')
    }

    if ($time_in_tarifs && $Plan_start_hour[$i] && $Plan_end_hour[$i])
    {
       if ($Plan_k[$i]<=0)
       {
          $out.=&RRow('*','L','Ограничения по времени суток, т.е. доступ в интернет будет разрешен только в определенное время суток')
       }
        else
       {
          $out.=&RRow('*','L',"В промежуток времени с $Plan_start_hour[$i] до $Plan_end_hour[$i] часов трафик будет засчитан с коэффициентом $Plan_k[$i]")
       }
    }

    $out.=&RRow('*','L',"Тарифный план предусматривает, что если вы не выработали все мегабайты трафика $c[1], то $c[2] трафик ".
      "может быть засчитан как $c[1] в соотношении: 1 $c[1] Мб = $Plan_m2_to_m1[$i] $c[2] Мб") if $Plan_m2_to_m1[$i];

    $out.=&RRow('*','L',"Скорость доступа ограничена $Plan_speed[$i] Кбит/сек") if $Plan_speed[$i];
 }

 $out&&=&Table('tbg1 nav2',$out);
 return $out;
}


sub SP_SetNextPaket3
{
 {
  last unless defined $F{paket};
  $Fpaket==$next_paket3 && &Error('Заказ тарифного плана не выполнен - вы выбрали тот же тарифный план, который уже заказан на следующий месяц.',$EOUT);

  $Fpaket && $Plans3{$Fpaket}{usr_grp_ask}!~/,$grp,/ && &Error('Заказ тарифного плана не выполнен - неразрешенный пакет.',$EOUT);

  &sql_do($dbh,"UPDATE users SET next_paket3=$Fpaket WHERE id=$Mid LIMIT 1");
  &Insert_Event_In_DB(428,$Fpaket? $Plans3{$Fpaket}{name_short} : '');

  &OkMess($Fpaket? 'Заказ смены тарифного плана следующего месяца на '.&bold($Plans3{$Fpaket}{name_short}).' выполнен.'.$go_main :
     'Вы дали указание в следующем месяце не изменять ваш текущий тарифный план.',$EOUT);
  return;
 }

 $out1 or return;

 $OUT.=&MessX(&div('big cntr','Заказ дополнительного тарифного плана на следующий месяц')).$br2.$out3;
}

# --- Смена доп.пакета текущего месяца ---

sub SP_SetPaket3
{
 {
  defined($F{paket}) or last;

  $Plans3{$Fpaket}{usr_grp_ask}!~/,$grp,/ && &Error('Смена тарифного плана не выполнена - неразрешенный пакет.',$EOUT);
  $Plans3{$Fpaket}{price_change}==0 && &Error('Смена тарифного плана не выполнена - на данный пакет не разрешено переключаться в середине месяца.',$EOUT);

  $F{balance}!=$balance && &Error('Обнаружено изменение вашего баланса. Возможно вы уже сменили тарифный план либо параллельно были проведены финансовые операции. '.
     'Смотрите раздел '.&ahref("$scrpt&a=115",'платежи'),$EOUT);
  $Fpaket==$paket3 && &Error('Смена дополнительного тарифного плана не выполнена - вы выбрали тот же тарифный план, который у вас в данный момент.'.$go_main,$EOUT);
  $got_money=$Plans3{$Fpaket}{price_change};
  $got_money>=$balance && &Error('На вашем балансе недостаточно средств для смены тарифного плана.',$EOUT);
  $coment="`$Plans3{$paket}{name_short}` на `$Plans3{$Fpaket}{name_short}`";
  $p_now=&commas($Plans3{$paket}{name_short});
  $p_want=&commas($Plans3{$Fpaket}{name_short});
  if ($act==51)
  {
     &OkMess("<span class='big story'>&nbsp;&nbsp;<span class=error>Внимание!</span>. В данный момент вы обслуживаетесь на тарифном плане $p_now. ".
       "Вы решили изменить его на тариф $p_want стоимостью $Plans3{$paket}{price_change} $gr Эта услуга платная, с вашего счета будет снято дополнительно ".
       &bold($got_money)." $gr".$br2.
       " После вашего согласия переключение будет произведено в течение нескольких минут, при этом сумма снятия будет посчитана так как будто вы ".
       "работаете на выбранном тарифном плане с начала месяца</span>.".$br3.
       &CenterA("$scrpt&act=52&balance=$balance&paket=$Fpaket",'Произвести смену тарифного плана').$br3.
       &CenterA($scrpt,'Отказаться'),$EOUT);
     return;
  }

  $coment="Смена тарифного плана $coment";
  $rows=&sql_do($dbh,"INSERT INTO pays SET mid=$Mid,cash=-($got_money),type=10,bonus='y',admin_id=$Adm->{id},admin_ip=INET_ATON('$RealIp'),coment='$coment',category=105,time=$ut");
  $rows<1 && &Error($V? "$V Ошибка создания платежа-снятия за смену тарифного плана" : "Временная ошибка. Повторите запрос позже.$go_back",$EOUT);

  $rows=&sql_do($dbh,"UPDATE users SET balance=balance-($got_money),paket3=$Fpaket WHERE id=$Mid LIMIT 1");
  $rows<1 && &ToLog("!! После платной смены тарифного плана произошла ошибка изменения баланса клиента id=$Mid. Уменьшите баланс на $got_money $gr");
  &sql_do($dbh,"UPDATE users SET paket3=$Fpaket WHERE mid=$Mid LIMIT 1");

  &OkMess(&div('big',"Смена тарифного плана выполнена. С вашего счета снято $got_money $gr").$go_main,$EOUT);
  return;
 }

 $out2 or return;

 $OUT.=&MessX(&div('big','Смена тарифного плана в текущем месяце. Внимание! Операция платная.').$br2.
   'Ниже в списке выберите тарифный план, на который вы хотите изменить свой текущий. '.
   'После выбора, в этот же момент будет произведена замена вашего текущего тарифа на новый. Новый тарифный план '.
   'будет действовать как будто он был установлен с начала текущего месяца, т.е. деньги по старому тарифу '.
   'не будут сниматься с вашего счета.',1,1).$out4;
}

sub SP_Select3
{
 ($url,$only_now_change_pkt)=@_;
 # $only_now_change_pkt - показывать только те пакеты, на которые можно перейти в текущем месяце (имеют стоимость перехода)

 $out='';
 foreach $i (sort {$Plans3{$a} cmp $Plans3{$b}} grep $Plans3{$_}{usr_grp_ask}=~/,$grp,/, keys %Plans3)
 {
    $t{$_}=$Plans3{$i}{$_} foreach ('name_short','price','price_change','descr');
    next if $only_now_change_pkt && $t{price_change}==0;
    $out.=&RRow('head','lc','Тарифный план',&ahref("$url&paket=$i",$t{name_short}));
    $out.=&RRow('* error','lr',"Стоимость перехода на данный тарифный план, $gr",&bold($t{price_change})) if $only_now_change_pkt; 
    $out.=&RRow('*','lr',"Цена, $gr",&bold($t{price}));
    $out.=&RRow('*','ll','Описание',&Show_all($t{descr}));
 }
 $out&&=&Table('tbg1 nav2',$out);
 return $out;
}

1;      
