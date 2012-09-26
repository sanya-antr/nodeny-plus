#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
#   Модуль опционных платежей 

# Структура опционного платежа, поле reason:  id_опции:время_окончания_действия:категория_трафика
# В одном платеже могу быть несколько опций, разделяются переводом строки

# Таблица описания опций:
#  opt_id	- id опции
#  opt_time 	- время действия, если =0, то это пак опций, список id содержится в поле opt_descr 
#  opt_descr	- текстовое описание опции

sub go
{
 $plg_id='payopt';
 $OUT.=&MessX('Раздел опционных платежей. '.&ahref("$scrpt&a=4",'Помощь'),1,1);

 %otime=();
 $sth=&sql($dbh,"SELECT reason FROM pays WHERE category=111 AND mid=$Mid ORDER BY time",'Активированные клиентом опции');
 while( $p=$sth->fetchrow_hashref )
 {
    @opts=split /\n/,$p->{reason};
    foreach $o (@opts)
    { 
       ($oid,$time)=split /:/,$o;
       $otime{$oid}=$time if !defined($otime{$oid}) || $time>$otime{$oid};
    } 
 }

 $Fopt=int $F{opt};			# номер заказанной опции или 0, если еще не заказывал
 $paket=$U{$Mid}{paket};
 $pays_opt=$Plan_pays_opt[$paket];	# через запятую перечислены номера опций доступные для пакета клиента
 $out='';				# список активированных опций
 $out1='';				# список всех доступных опций
 $out2='';				# список всех доступных паков
 %o=();					# параметры опции, которую выбрал клиент
 %odescr=();
 # time=0 - признак того, что это указатель на собрание (пак) опций
 $sth=&sql($dbh,"SELECT * FROM pays_opt WHERE opt_time>0 ORDER BY opt_name",'Список всех существующих опций');
 while( $p=$sth->fetchrow_hashref )
 {
    $oid=$p->{opt_id};
    next if $pays_opt!~/,$oid,/;	# пакет клиента не предусматривает эту опцию
    ($opay,$otime,$ocls)=&Get_fields('opt_pay','opt_time','trf_class');
    ($oname,$odescr{$oid})=&Get_filtr_fields('opt_name','opt_descr');
    # время действия опции в виде: х дней y часов z минут
    $days=int $otime/86400;		# дней
    $min=int(($otime % 86400)/60);	# минут
    $time="$days дней ";
    $time.=(int $min/60).' час '.($min % 60).' мин' if $min;
    $out1.=&RRow('*','clll',&bold($opay),&ahref("$scrpt&opt=$oid",$oname),$time,$odescr{$oid});
    ($o{pay},$o{name},$o{descr},$its_pack)=($opay,$oname,$odescr{$oid},0) if $oid==$Fopt;
    $odescr{$oid}.=". Срок действия $time" if $time;

    # если опция активирована - добавим в список активированных
    if( $otime{$oid}>$t )
    {  # время опции не вышло
       $out.=&bold($oname).'. Опция действительна до '.&bold(&the_time($otime{$oid}));
       $out.=$br2;
    }    
 }

 @opts=(); # список опций, входящих в пак, если клиент выбрал пак через $Fopt
 $sth=&sql($dbh,"SELECT * FROM pays_opt WHERE opt_time=0 ORDER BY opt_name",'Получим паки опций');
 while( $p=$sth->fetchrow_hashref )
 {
    ($oid,$opay)=&Get_fields('opt_id','opt_pay');
    ($oname,$odescr)=&Get_filtr_fields('opt_name','opt_descr');
    next if $pays_opt!~/,$oid,/;	# пакет клиента не предусматривает эту опцию
    $descr='';
    foreach (split /,/,$odescr)
    {
       $i=int $_;
       next if !$i || !defined($odescr{$i});
       $descr.=$odescr{$i}.$br2;
       push @opts,$i if $oid==$Fopt;
    }
    next unless $descr;			# нет ни одной опции в паке - ошибка в данных пака
    $out2.=&RRow('*','cll',&bold($opay),&ahref("$scrpt&opt=$oid",$oname),$descr);
    ($o{pay},$o{name},$o{descr},$its_pack)=($opay,$oname,$descr,1) if $oid==$Fopt;
 } 

 &Error("В вашем тарифном плане опционные платежи не предусмотрены.",$EOUT) if !$out1 && !$out2;
 ($F{ok} eq 'no') && &Error("Вы отказались от покупки опции.",$EOUT);

 if( !$Fopt )
 {
    $OUT.=$br.&div('message lft','Активные опции:'.$br2.$out).$br if $out;
    if( !$out || !$F{dontshowopt} )
    {
       $OUT.=&div('lft',&Table('tbg3 nav2',&RRow('head','cclc',&bold_br("Стоимость, $gr"),'Опция','Срок действия','Описание').$out1)) if $out1;
       $OUT.=$br.&div('lft',&Table('tbg3 nav2',&RRow('head','ccc',"Стоимость, $gr",'Пак','Описание').$out2)) if $out2;
    } 
    return;
 }

 defined($o{name}) or &Error("Ошибочный номер опции. Операция отменена.",$EOUT);

 $final_balance=sprintf("%.2f",$U{$Mid}{final_balance});

 # использую слово "повторный" т.к. "дублирующий" тупые клиенты не поймут
 &Error("Опция не активирована т.к. система зафиксировала изменение ваших данных: либо параллельно осуществлен платеж либо вы ".
   "повторно послали запрос на активацию услуги (например обновили страницу). ".&ahref("${scrpt}a=115",'Смотрите раздел платежей')." на предмет ".
   "была ли активирована заказываемая услуга.",$EOUT) if $F{ok} eq 'yes' && abs($F{balance}-$final_balance)>0.01;

 $OUT.="<div class='message nav2' align=justify>".
   &Printf('[br]Вы выбрали опцию [bold] стоимостью [bold] [][br2]Описание опции:[br2][][br2]',$o{name},$o{pay},$gr,$o{descr});
 $tend='</div>'.$go_back.$EOUT;
 ($final_balance-$o{pay})<0 && &Error("К сожалению на вашем счете ($final_balance $gr) недостаточно средств для активации данной услуги ($o{pay} $gr).",$tend);

 if( $F{ok} ne 'yes' )
 {
    $OUT.=&bold('Внимание').
      ". Если вы согласны с покупкой данной услуги нажмите кнопку &#171;Покупку опции подтверждаю&#187;. После чего с вашего счета будет снята сумма ".
      "<b>$o{pay} $gr</b> <span class=error>После подтверждения покупки данной услуги, вы не сможете отменить эту покупку!</span><br><br><br><br>".
      &div('cntr',
        &Table('table2',
          &RRow('','ll',
            &form('!'=>1,'opt'=>$Fopt,'ok'=>'yes','balance'=>$final_balance,&submit_a('Покупку опции подтверждаю')),
            &form('!'=>1,'ok'=>'no',&submit_a('ОТКАЗЫВАЮСЬ'))
          )
        )
      ).$tend;
    return;
 }

 @opts=($Fopt) if !$its_pack;
 $reason=$coment=$payopt='';
 foreach $o (@opts)
 {
    $p=&sql_select_line($dbh,"SELECT * FROM pays_opt WHERE opt_id=$o LIMIT 1");
    $p or &Error("Опция не активирована. Внутренняя ошибка ($plg_id-1). Попробуйте запрос позже.",$tend);
    ($otime,$cls,$oname,$opay)=&Get_fields('opt_time','trf_class','opt_name','opt_pay');

    $when=$t+$otime;
    $opt_name=&Filtr($oname);
    $coment.="Активация опции: $opt_name. Действие закончится ".&the_date($when);

    $reason.="$o:$when:$cls:0:0\n";
    $payopt.="$cls:0\n";

    $coment.="\n\n";
 }

 $reason or &Error("Опция не активирована. Внутренняя ошибка ($plg_id-2). Попробуйте запрос позже.",$tend);
 chop $reason;
 chop $coment;
 chop $coment;

 $coment="Пак опций: ".&Filtr_mysql($o{name})."\n\n$coment" if $its_pack;
 $rows=&sql_do($dbh,"INSERT INTO pays SET mid=$Mid,cash=-($o{pay}),type=10,bonus='y',category=111,admin_id=$Adm->{id},admin_ip=INET_ATON('$RealIp'),".
   "reason='$reason',coment='$coment',time=$ut");

 $rows<1 && &Error("Активация опции не выполнена. Внутренняя ошибка ($plg_id-3). Попробуйте запрос позже.",$tend);

 $payopt=~s|[\\']||g;
 $payopt && &sql_do($dbh,"UPDATE users_trf SET options=CONCAT('$payopt',options) WHERE uid=$Mid LIMIT 1");

 $rows=&sql_do($dbh,"UPDATE users SET balance=balance-($o{pay}) WHERE id=$Mid LIMIT 1");
 if( $rows<1 )
 {
    Pay_to_DB(uid=>$Mid, type=>50, category=>510);
    &Error("Активация опции выполнена частично. Внутренняя ошибка ($plg_id-4). Сообщите об этом админстрации.",$tend);
 } 

 $OUT.='</div>'.$br;
 &OkMess("Оплата опции выполнена успешно. ".&bold('Опция будет активирована в течение нескольких минут').$br2.&ahref("$scrpt&a=115",'Посмотреть платежи')); 
}

1;      
