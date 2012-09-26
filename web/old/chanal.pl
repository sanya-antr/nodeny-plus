#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

# Формирование url-а на данные клиента
sub ShowClient
{
 my($id,$title) = @_;
 return $Url->a($title, a=>'user', id=>$id);
}

$pix_for_traf=150; # количество пикселей по оси Х в загруженности канала

$a=$scrpt;
$Fmid=int $F{mid};
$Fmid<0 && &Error("Неверно задан id клиента, действие отменено.");
$Fc=int $F{c};			# код функции
$Fsort=int $F{sort};
$Fclass=int $F{class};
$Fwhen=int $F{when};		# время заказанного среза
$Fshowip=int $F{showip};	# показывать имя или ip
$Falias=int $F{alias};

$sth=&sql($dbh,"SELECT * FROM nets WHERE preset=0 AND priority=0",'Названия направлений нулевого пресета');
while ($p=$sth->fetchrow_hashref)
{
   $i=$p->{class};
   ${"Ncls$i"}=v::filtr($p->{comment});
}
${"Ncls$_"}||="Направление $_" foreach (1..8);
$Ncls0="Общий";

# ---  меню слева  ---
$out='&nbsp;Сейчас '.bold($ses::time_now).$br2.
     &ahref("$a&c=4&ed=1",'Детализация');
$out.=&ahref("$a&c=5",'Персональная детализация') if $Adm->{pr}{detail_traf};
$out.=&ahref("$a&class=-1",'Неучтенный трафик').
     &ahref("$a&graf=1&class=1",'График');
$out.=&ahref("$a&c=1",'Суточная статистика') if $Adm->{pr}{92};
$out.=&ahref("$a&c=6",'Статистика авторизаций') if $Adm->{pr}{106};

ToLeft Menu($out);

$OUT.="<table cellpadding=0 cellspacing=4 class=width100><tr><$tc valign=top>";
$tend="</td></tr></table>";

%subs=(
 0 => \&chanal_load,
 1 => \&day_stat,
 4 => \&v_stat,
 5 => \&list_detail,
 6 => \&auth_stat,
);

$Fc=0 unless defined $subs{$Fc};

&{ $subs{$Fc} };

$OUT.=$tend;

Exit();

# --------------------
# Вход:
#  0	- id клиента
#  1	- url
# Выход:
#  0	- табличка с данными клиента
#  1	- группа клиента
#  2	- id основной записи
#  3	- список всех алиасов, включая основную
#  4	- количество алиасных записей
#  5	- табличка со всеми алиасами
#  6    - пакет клиента

sub GetUserInfo2
{
 my($id,$url)=@_;
 my($sth,$p,$h,$aliases,$allId,$alias_count,$s,$paket);
 $id or Error("Ломанул! Молодец!");
 $s = '&nbsp;&nbsp;';
 my $p = ShowUserInfo($id);
 my $userinfo = $p->{full_info};
 my $mId = $id;
 my $grp = $p->{grp};
 $Adm->{grp_lvl}{$grp} or Error("Клиент в группе, доступ к которой вам запрещен.",$tend);
 $aliases='';
 $allId='';
 $alias_count=-1;
 $sth = sql($dbh,"SELECT id,mid,name,paket FROM users WHERE id=$mId",'Все записи клиента, включая основную и алиасы');
 while( $p=$sth->fetchrow_hashref )
 {
    $h = $p->{id};
    $aliases .= &RRow('*','lll','',$s.v::filtr($p->{name}).$s,$s.&ahref("$a&mid=$h",'стат').$s);
    $alias_count++;
    $allId .= "$h,";
    $paket = $p->{paket};
 }
 $paket or &Error('Не удалось получить номер тарифного плана для заданного клиента.');
 chop $allId;
 $aliases=$br2.&Table('tbg1i',$aliases);
 return($userinfo,$grp,$mId,$allId,$alias_count,$aliases,$paket);
}

# ---------------------------------------------
#		Загрузка канала
# ---------------------------------------------

sub chanal_load
{
 !$Fclass && !$Adm->{pr}{detail_traf} && Error("Нет прав на просмотр детализации трафика.",$tend);

 # получим самую позднюю отметку времени завершенного среза в таблице traf_info, не делать select max(time) - если нет строк - будет null,
 # а нам надо знать что таблица может быть пустой. cod=15 - гарантирует, что ядром все работы по срезу закончены
 $p=&sql_select_line($dbh,"SELECT time FROM traf_info WHERE cod=15 ORDER BY time DESC LIMIT 1",'Время последнего завершенного среза'); 
 $p or &Error($Adm->{pr}{SuperAdmin}? 'Таблица traf_info, содержащая данные о ходе записи трафика, пуста. Проверьте запущено ли ядро NoDeny.':'Нет данных.',$tend);
 $tmax=$p->{time};
 # время действительно самого последнего среза, обработка которого возможно еще не завершена
 $p=&sql_select_line($dbh,"SELECT time FROM traf_info ORDER BY time DESC LIMIT 1",'Время самого последнего среза');
 $trealmax=$p? $p->{time} : 0;

 &DB2_Connect;
 # Если самая поздняя отметка времени меньше текущего на 4 периода срезов трафика, значит что-то случилось - выведем предупреждение.
 # Если периоды меньше 4 минут, то установим 16 минут, а не 4 периода
 $Kern_t_traf=60 if $Kern_t_traf<60;
 $i1=$Kern_t_traf>240? $Kern_t_traf*4 : 960;
 if( $ses::t>($trealmax+$i1) )
 {
    $i2=($ses::t-$trealmax)/60;
    $i1=$i2 % 60;
    $i2=int $i2/60;
    $OUT.=&div('message lft',"Внимание. За последние $i2 часов $i1 минут нет информации о ходе записи трафика. Проверьте запущено ли ядро NoDeny.") if $Adm->{pr}{SuperAdmin};
 }

 $Fgraf=int $F{graf};			# 1 - вывод графика
 $Fclass=1 if !$Fclass && $Fgraf;	# график детализации не разрешен
 $Fed=int $F{ed};			# единица измерения
 $ed=('Мбайт','Мбайт','кбайт','кбайт','байт','кбайт/сек','кбит/сек','Мбайт/сек')[$Fed]||'Мбайт';

 # рабочий урл
 my $url = $Url->new(ed=>$Fed, class=>$Fclass);
 $a.="&ed=$Fed&class=$Fclass";
 $a.="&showip=1" if $Fshowip;
 $url->{showip}=1 if $Fshowip;
 $a.="&graf=1" if $Fgraf;
 $url->{graf}=1 if $Fgraf;
 $a.="&when=$Fwhen" if $Fwhen;	# заказанный срез
 $url->{when}=$Fwhen if $Fwhen;
 $a.="&sort=$Fsort" if $Fsort;	# режим сортировки
 $url->{sort}=$Fsort if $Fsort;

 $t_srez=$Fwhen || $tmax;	# если срез не указан, то возьмем самый последний
 $now_stat=$Fgraf? '' : ' зарегистрированная в '.the_short_time($t_srez,$ses::t);
 $now_stat.=!$Fclass? ' детализированная статистика': $Fclass<9? ' статистика трафика `'.${"Ncls$Fclass"}.'`' : ' статистика трафика всех направлений';

 $right_col='';
 $show_detail_ip=0;
 if( $Fmid )
 {
    ($userinfo,$grp,$mId,$allId,$alias_count,$aliases,$paket)=&GetUserInfo2($Fmid,$a);
    $url->{mid} = $Fmid;
    $a.="&mid=$Fmid";
    $WHERE="WHERE mid=$Fmid";
    if( $alias_count )
    {
        if( $Falias )
        {
            $url->{alias} = 1;
            $a.="&alias=1";
            $WHERE="WHERE mid IN ($allId)";
            $right_col.=&div('borderblue row1 cntr',"Показана $now_stat клиента, включая все его учетки: $aliases<br>").'<br>';
        }else
        {
            $right_col.=&div('nav3 modified',&ahref("$a&alias=1",'Показать суммарную статистику всех учетных записей клиента')).'<br>'.
              &div('borderblue row1 lft',"Показана $now_stat учетной записи:<br>$userinfo<br>Обратите внимание: у текущей записи есть дополнительные записи (алиасы). ".
              "Статистика ведется на каждый алиас отдельно: $aliases".$br2).$br;
        }
    }
     else
    {
        $right_col.="Показана $now_stat для учетной записи:".$br.$userinfo.$br;
    }
    $for_client='клиента';
 }
  else
 {
    $WHERE='WHERE 1';
    ToTop "Показана $now_stat всей сети";
    $for_client='всей сети';
 }

 $a2="$a&start=$F{start}";
 $right_col.=&ahref("$a&class=0",'Детализация текущего среза').$br if $Fclass && !$Fgraf && $Adm->{pr}{detail_traf};
 $right_col.=&ahref("$a&class=1",'Убрать детализацию среза').$br if !$Fclass && !$Fgraf;
 $right_col.=&ahref("$a&class=1&graf=1",'График загрузки канала').$br if !$Fclass || !$Fgraf;
 $right_col.=&ahref("$a&c=4&last_time=$t_srez",'График детализации').$br;
 $right_col.=&ahref("$a&mid=0",'Показать всех в данный срез').$br if $Fmid && !$Fgraf;
 $right_col.=&ahref("$a&mid=0",'Показать загрузку канала сетью').$br if $Fmid && $Fgraf && $Fclass;
 $right_col.=$br.&Table('nav3',
   &RRow('row3','lll',&ahref("$a2&ed=1",'целые Мбайт'),&ahref("$a2&ed=0",'Мбайт'),&ahref("$a2&ed=7",'Мбайт/сек')).
   &RRow('row3','lll',&ahref("$a2&ed=3",'целые кбайт'),&ahref("$a2&ed=2",'кбайт'),&ahref("$a2&ed=5",'кбайт/сек')).
   &RRow('row3','lll',&ahref("$a2&ed=4",'байт'),'',&ahref("$a2&ed=6",'кбит/сек'))
 ).$br3;
 my $temp = &ahref("$a&class=9","По всем направлениям трафика $for_client").$br; 
 $temp.=&ahref("$a&class=$_",${"Ncls$_"}.' '.$for_client) foreach (1..8);
 $right_col.= Menu($temp);

 $header='';

 $tm=localtime($t_srez);
 $tname=(1900+$tm->year).'x'.(1+$tm->mon).'x'.$tm->mday; # часть имени таблицы для трафика запрошенного дня
 if( $Fclass )
 {
    $base_time=0;
    $lname='y';			# имя таблицы с трафиком начинается с этого символа
    $d_trf_tbl="y$tname";	# имя таблицы с трафиком запрошенного дня
 }else
 {# в таблице детализации время относительно начала дня
    $base_time=timelocal(0,0,0,$tm->mday,$tm->mon,$tm->year);
    $lname='z';
    $d_trf_tbl="z$tname";
    # понадобится подпрограмма определения к какому направлению отнести ip
    require 'nNet.pl';
    &LoadMoneyMod;
    ($nets,$err_mess)=&nNet_NetsList; # ссылка на массив со списком сетей
    $err_mess && &Error("Детализированная статистика не может быть отображена. $err_mess");
 }

 if( $Fgraf )
 {  # Заказан вывод графика
    $Max_line_chanal=int (3600*24/$Kern_t_traf);
    $select.="SUM(`in`),SUM(`out`)";			# выбираемые поля
    $GROUP_BY="GROUP BY time ORDER BY time DESC";
    $header.="<table class='table0 sml width100'>";	# при рисовании графика уменьшим шрифт
    $header.=&RRow('head nav','cc rrc','Срез','График','',"К клиенту, $ed","От клиента, $ed",'% от максимального<br>значения в сутки');
 }
  else
 {
    $t_traf=$t_srez-$base_time;
    $WHERE.=" AND time=$t_traf";

    $p=$Fclass? &sql_select_line($dbs,"SELECT SUM(`in`) AS t FROM $d_trf_tbl WHERE time=$t_traf".($Fclass<9 && " AND class=$Fclass"),
      'Максимальное значение входящего трафика за срез') : 0;
    $max_traf_srez=$p? $p->{t}||1 : 1;

    $Max_line_chanal||=16; # 16 строк выведем если не указано сколько
    $select=$Fclass>0? 'mid,`in`,`out`' : $Fclass? '`in`,`out`' : 'mid,bytes,direction,port,proto,INET_NTOA(ip)';

    $GROUP_BY='ORDER BY ';
    $GROUP_BY.=$Fclass? '`in` DESC,`out` DESC' : ($Fsort==1? 'proto,port,' : $Fsort==2? 'proto DESC,port,':'').'bytes DESC';

    $p=&sql_select_line($dbs,"SELECT time FROM $d_trf_tbl WHERE time<$t_traf ORDER BY time DESC LIMIT 1",'Время предыдущего среза');
    $t_prev=$p? $p->{time}+$base_time : 0;
    $t1=$p? &ahref("$a&when=$t_prev",'&larr;'," title='Предыдущий срез'") : '';
    $p=&sql_select_line($dbs,"SELECT time FROM $d_trf_tbl WHERE time>$t_traf ORDER BY time LIMIT 1",'Время следующего среза');
    $t_next=$p? $p->{time}+$base_time : 0;
    $t2=$p? &ahref("$a&when=$t_next",'&rarr;'," title='Следующий срез'") : '';

    $t_period=$t_prev && ($t_srez-$t_prev); # равный нулю период указывает, что он неизвестен
    $t_period_text=$t_period? ($t_period>=60 && &bold(int $t_period/60).' мин ').&bold($t_period % 60).' сек' : '';

    if( $Fclass<0 )
    {
       $user_cell='Коллектор: источник &rarr; приемник';
       @from_to=("К источнику, $ed","От источника, $ed");
    }else
    {
       $user_cell = $Fshowip? &CenterA("$a&start=$F{start}&showip=0",'&rarr; Имя') : &CenterA("$a&start=$F{start}&showip=1",'&rarr; IP');
       @from_to=("К клиенту, $ed","От клиента, $ed");
    }

    $header.="<table class='tbg width100'>".
       &RRow('head nav','6','Срез: '.&bold(&the_short_time($t_srez,$ses::t)).'. Длительность среза: '.($t_period_text || 'не установлена')).
       &RRow('head nav','cccccc',&Center(&div('nav',"$t1 $t2")),$user_cell,@from_to,
        $Fclass? ("% загрузки в срез",'') : ('Удаленный адрес','Направление') );
 }


 if( $Fclass<0 )
 {  # запрошен показ `неучтенного трафика`
    $d_trf_tbl='traf_lost';
    $select.=',ip';
    $list_of_days='';
 }
  elsif ($Fclass)
 {
    $WHERE.=" AND class=$Fclass" if $Fclass<9;
    # Получим список дней на которые есть статистика, этот список получим из названий таблиц
    $list_of_days=&Get_list_of_stat_days($dbs,$lname,"$a&graf=1&when=",$t_srez);
 }
  else
 {
    $list_of_days=&Get_list_of_stat_days($dbs,'v',"$scrpt&c=4&ed=4&mid=$Fmid&when=",$t_srez);
 }

 $sum1=$sum2=0;
 $sql_end="FROM $d_trf_tbl $WHERE $GROUP_BY";
 # $dbs !!!
 ($sql,$page_buttons,$rows,$db) = Show_navigate_list("SELECT $select,time $sql_end", $F{start}, $Max_line_chanal, $url);

 $page_buttons = &RRow('tablebg',6, _('[div h_left]',$page_buttons));
 $OUT.=$header.$page_buttons;

 if ($Fgraf) {&chanal_graf} else {&chanal_srez}

 $OUT.=$page_buttons.'</table>'.$br;

 $OUT.=&div('message lft',"Выше приведен трафик, который не был начислен ни одному клиенту, поскольку ядро биллинга по текущим настройкам ".
   "не смогло сопоставить его с определенным клиентом. Причины этого могут быть такими:".$br2.
   "1) для определенных клиентских сетей вы не указали с каких коллекторов необходимо учитывать трафик, поскольку пакет может пройти через ".
    "несколько маршрутизаторов с коллекторами, то он мог бы быть учтенным не один раз;".$br2.
   "2) неправильная настройка фаервола, в котором трафик отсылается в коллекторы. Например, пакет может быть помечен как идущий к клиенту, однако ".
    "адрес назначения не является клиентским ip;".$br2.
   "3) неправильно настроенная агрегация в ipcad.conf, при которой 'обрезаются клиентские ip'.").$br if $Fclass==-1;

  $OUT.=&div('borderblue',"<table class=width100><tr><$tc valign=top width=50%>".&ShowTrafInfo($t_srez,"Статистика отображаемого среза трафика")."</td><$tc valign=top>".
            &ShowTrafInfo($trealmax,"Статистика последнего обработанного среза трафика").'</table>') unless $Fmid; # статистика ядра

  $OUT.="</td><td valign=top width=17%>".&Mess3('row2',$right_col).$list_of_days;
}

sub chanal_srez
{
 %U=();
 while( my %p = $db->get_line )
 {
  @cell=('','','','','','');
  {
   if( $Fclass<0 )
   {  # `неучтенный трафик`
      $cell[1]=&Table('table1 width100',&RRow('','lr',split /-/,$p{ip}));
      last;
   }

   $mid=$p{mid};
   $cell[0].=&ahref("$a&when=$t_srez&mid=$mid&class=0",'Дет').' | ' if $Fclass || !$Fmid;
   $cell[0].=&ahref("$a&when=$t_srez&mid=$mid&c=4&last_time=$t_srez",'Граф') unless $Fmid;

   if( $U{$mid}{ip} )
   {
      $ipp=$U{$mid}{ip};
      $name=$U{$mid}{name};
      $grp=$U{$mid}{grp};
      $preset=$U{$mid}{preset};
   }else
   {
      $h=$dbh->prepare("SELECT * FROM users WHERE id=$mid LIMIT 1");
      $h->execute;
      debug("(select user id=$mid)");
      if( $h=$h->fetchrow_hashref )
      {
         $ipp=$h->{ip};
         $name = $h->{name};
         $grp=$h->{grp};
         $preset=$Plan_preset[$h->{paket}];
      }else
      {
         $name="<span class=error>Нет в базе id: $mid</span>";
         $ipp='x.x.x.x';
         $grp=0;
         $preset=-1;
      }
      $U{$mid}{ip}=$ipp;
      $U{$mid}{name}=$name;
      $U{$mid}{grp}=$grp;
      $U{$mid}{preset}=$preset;
   }

    $cell[1]=!$Adm->{grp_lvl}{$grp}? '&nbsp;': 
        $Fshowip? $Url->a($ipp, a=>'user', id=>$mid, -title=>$name) : $Url->a($name, a=>'user', id=>$mid, -title=>$ipp);
  }

  {
   if( $Fclass )
   {
      # исходящий может быть выделен болдом если он больше входящего
      $traf1=$p{in};
      $traf2=$p{out};
      $trafb=&Print_traf($traf2,$Fed,$t_period);
      $trafb=&bold($trafb) if $Bold_out_traf && $traf1 && $traf2>$traf1;
      $cell[2]=&Print_traf($traf1,$Fed,$t_period);
      $cell[3]=$trafb;
      if( $t_period )
      {  # выведем % загрузки канала
         $traf1*=100;
         $cell[4]= _('[span data1]',int($traf1/$max_traf_srez +.5));
      }
      last;
   }

   # детализированный траф
   $cell[$p{direction}? 3:2]=&Print_traf($p{bytes},$Fed,$t_period);

   $ip_id||=50; # начнем отсчитывать с 50 id поля с ip 
   $ipp=$p{'INET_NTOA(ip)'};
   $port=$p{port};
   if( $preset>=0 )
   {
      $nclass=&nNet_GetIpClass($ipp,$port,$nets->{$preset});
      $nclass=$nclass<0? _('[span disabled]','ошибка') : ('Бесплатный', Get_Name_Class($preset))[$nclass];
      $nclass= Table('table1 width100',&RRow('','lr',$Presets{$preset},$nclass)) if !$Fmid;
   }else
   {
      $nclass='';
   }

   ($proto,$class_row)=&GetProto($p{proto},$port);

   if( $Adm->{grp_lvl}{$grp} )
   {
      $cell[4]="$g $ipp $proto";
      $cell[5]=$nclass;
      $ip_id++;
   }else
   {
      $cell[4]= _('[span disabled]', 'скрыто');
   }
  }
  $OUT.=&RRow('*','llrrrr',@cell);
 }
}

sub chanal_graf
{
 @U=();
 $max_traf=1;
 while( my %p = $db->get_line )
 {
    $t_check = $p{'time'};
    $traf1 = $p{'SUM(`in`)'};
    $traf2 = $p{'SUM(`out`)'};
    $max_traf=$traf1 if $traf1>$max_traf;
    push @U,($t_check,$traf1,$traf2);
 }
 while( $t_check=shift @U )
 {
    $traf1=shift @U;
    $traf2=shift @U;
    $t_check+=$base_time;
    $t_prev=int $U[0]; # надо int т.к. $U[0] может быть неопределен когда стал пустым @U
    $t_period=$t_prev && ($t_check-$t_prev);
    $OUT.=&PRow."<td nowrap>&nbsp;";
    $OUT.=sprintf("%02d.%02d.%02d ",$tm->mday,$tm->mon+1,$tm->year-100) if $ses::day_now!=$tm->mday || $ses::mon_now!=($tm->mon+1);
    $OUT.=&ahref("$a&when=$t_check&graf=0",&the_hour($t_check)).'</td>'.
       "<td nowrap width=$pix_for_traf><img src='$img_dir/fon1.gif' width=".int($traf1*$pix_for_traf/$max_traf)." height=11></td>".
       "<td><img src='$img_dir/fon1.gif' width=1 height=11></td>";
    $OUT.= _('[td h_center]', Print_traf($traf1,$Fed,$t_period));
    unless ($Fclass) {$OUT.="<td>&nbsp;</td><$td>".&split_n($traf2)."&nbsp;&nbsp;&nbsp;</td></tr>"; next}
    $OUT.="<$td>".&Print_traf($traf2,$Fed,$t_period).'</td>';
    if( $t_period )
    {  # выведем загрузку канала для текущей строки
       $OUT.= _('[td h_center data1]', int($traf1*100/$max_traf +.5));
    }else
    {
       $OUT.= _('[td]', '');
    }
    $OUT.='</tr>';
 }
}


# --------------
sub ShowTrafInfo
{
 my ($sth,$p,$cod,$data1,$server);
 my ($t1,$out)=@_;
 my $complete=0;
 my $s=();
 foreach $nserver (keys %Collectors)
 {
    $s{$1}=$2 if $Collectors{$nserver}=~/^(.+?)\-(.+)$/;
 }

 $out="<table class='tbg1 width100'><tr class=head><$tc colspan=3>$out: ".&bold(&the_short_time($t1,$ses::t))."</td></tr>";
 $sth=&sql($dbh,"SELECT * FROM traf_info WHERE time=$t1 ORDER BY cod",'статистика хода обработки трафика ядром');
 while ($p=$sth->fetchrow_hashref)
 {
   $cod=$p->{cod};
   next if $cod==29; # код, указывающий какой тип трафика уже записан в бд
   if( $cod==8 )
   {
      foreach $cod (split /\n/,$p->{data1})
      {
         next if $cod!~/^(.+): *(\d+) *$/;
         ($server,$data1)=($1,$2);
         $out.=&RRow('*','rrl',"<table width=90% class=table0><tr><td>$s{$server}</td><$td>$server</td></tr></table>",&bold(&split_n($data1)),'байт');
      }
      next;
   }
   $data1=&bold($p->{data1});
   $out.=&RRow('*','lrl',
     $cod==1? ('Количество обработанных строк<br>от коллекторов трафика',$data1,'') :
     $cod==2? ("Время обсчета направлений",$data1,'сек') :
     $cod==3? ("Время добавления трафика<br>к текущим значениям в базе данных",$data1,'сек') :  
     $cod==4? ("Время получения данных трафика<br>для передачи клиентам",$data1,'сек') :
     $cod==5? ("Записей в кеше адресов обсчета направлений",$data1,'') :
     $cod==9? ("Время отключения абонентов превысивших лимиты",$data1,'сек') :
     $cod==10? ("Количество клиентов однократно превысивших допустимое количество потоков","<span class=error>$data1</span>",'') :
     $cod==14? ("Записан детельный трафик на ",$data1,'%') :
     $cod==15? ("Время записи детализации трафика",$data1,'сек') :
     $cod==20? ("<span class=error>Не получен ответ от ipcad на сервере</span>",$data1,'Трафик не учтен') :
     $cod==21? ("<span class=error>Не получено подтверждение о перемещении данных коллектора ipcad в чекпоинт, сервер</span>",$data1,'Трафик не учтен') :
     $cod==22? ("<span class=error>Не получены данные от коллектора ipcad на сервере</span>",$data1,'Трафик не учтен') :
     $cod==23? ("<span class=error>Проблемы в дополнительной базе данных</span>, не выполнено",$data1,' sql-запросов c данными трафика') :
               ($cod,$data,''));
     $complete=1 if $cod==15;
 }
 $out.="<tr class=rowoff><$tc colspan=3>Процедура обработки трафика за текущий срез не завершена.</td></tr>" if !$complete;
 return "$out</table>";
}

# ----------------------------------------------------------------------------
# выведем общий список клиентов у которых включена детализированная статистика
# ----------------------------------------------------------------------------
sub list_detail
{
    Error("Нет прав на просмотр детализации трафика.",$tend) if !$Fclass && !$Adm->{pr}{detail_traf};
    my $Allow_grp = join(',',keys %{$Adm->{grp_lvl}});
    $sql="SELECT * FROM users WHERE detail_traf<>0 AND grp IN ($Allow_grp) ORDER BY id";
    $sth=&sql($dbh,"$sql LIMIT 1",'Список клиентов с персонально включенной детализацией');
    if( ! $sth->rows )
    {
        ToTop 'Нет клиентов с <em>персонально</em> включенной детализированной статистикой';
        return;
    }

    $out='';
    ($sql,$page_buttons,$rows,$db) = Show_navigate_list($sql,$F{start},$cfg::Max_list_users,url->new(a=>$F{a},c=>5));
    while( my %p = $db->get_line )
    {
        $id = $p{id};
        $out.=&PRow.("<td>".(v::filtr($p{name}) || '&nbsp;')."</td><td>".v::filtr($p{fio})."</td>").'<td>'.
            ahref("$a&a=user&id=$id",v::filtr($p{ip}))."</td><$tc>".&ahref("$scrpt&a=$F{a}&&mid=$id&graf=1&class=0",'Статистика').'</td></tr>';
    }

    $colspan=4;
    $page_buttons&&=&RRow('head',$colspan,$page_buttons);
    $OUT .= Table('tbg1 width100',
        RRow('head nav',$colspan,'Клиенты, для которых персонально включена детализированная статистика').
        RRow('head','cccc','Логин','ФИО','IP','Статистика').
        $page_buttons.$out
    );
}

# ---------------------------------
#    Cуточная статистика трафика
# ---------------------------------

sub day_stat
{
 &LoadMoneyMod;
 &DB2_Connect;

 $Fclass||=1;
 $Fday=int $F{day};
 $Fmon=int $F{mon};
 $Fmon=$Fmon<1 || $Fmon>12? $ses::mon_now : $Fmon;

 # Сформируем список групп, включая объединения групп, с отмеченными галками
 ($out_left,$grp_sel)=&List_select_grp;

 $need_fields='id,mid,grp,name,ip';
 if( $Fmid )
 {
    $where="AND t.mid=$Fmid GROUP BY t.mid";
    $p=&sql_select_line($dbh,"SELECT $need_fields FROM users WHERE id=$Fmid LIMIT 1");
    $p or &Error("Не могу получить данные клиента id=$Fmid.",$tend);
    $Adm->{grp_lvl}{$p->{grp}} or Error("Клиент находится в недоступной вам группе. Просмотр суточной статистики заблокирован.",$tend);
    $ipp=$p->{ip};
    $sth=&sql($dbh,"SELECT $need_fields FROM users WHERE id=$Fmid LIMIT 1");
 }
  elsif (!$Adm->{pr}{92})
 {
    &Error("Нет прав на просмотр общей суточной статистики трафика.",$tend);
 }
  else
 {
    my $Allow_grp = join ',',keys %{$Adm->{grp_lvl}};
    $where='AND u.grp IN ('.($grp_sel eq ''? $Allow_grp : $grp_sel).')';
    $where.='GROUP BY t.mid'  if $Fday;
    $sth=&sql($dbh,"SELECT $need_fields FROM users");
 }

 $t1_sql=0;
 $j=0;
 $sql='';
 @f=split/,/,$need_fields;
 $lastrow=0;
 while( ($p=$sth->fetchrow_hashref) || ($lastrow=1) )  # $lastrow=1, не == !
 {
    if( $p )
    {
       $sql.='(';
       foreach $i (@f) { $sql.="'".&Filtr_mysql($p->{$i})."'," }
       chop $sql;
       $sql.='),';
       next if ++$j<400;
    }
    chop($sql) or last;

    $sql="REPLACE INTO user_select ($need_fields) VALUES $sql";

    $dbs->do($sql);

    $lastrow && last;
    $j=0;
    $sql='';
 }

 %tbl_is=();
 $sth = sql($dbs,"SHOW TABLES");
 $sth or Error('Ошибка получения списка таблиц.',$tend);
 while( $p=$sth->fetchrow_arrayref )
 {
    $tbl_is{$p->[0]}=1;
 }

 $mon_list = Set_mon_in_list($Fmon);
 $Fyear=int $F{year} || $ses::year_now;
 $list_year=&Set_year_in_list($Fyear);

 # Получим названия направлений действительных на выбираемый месяц
 if( $Fmon==$ses::mon_now && $Fyear==$ses::year_now )
 {  # Просмотр текущего месяца, поэтому направления текущие, по нулевому пресету
    @c=('', Get_Name_Class(0));
    $max_day = $ses::day_now;
 }
  else
 {  # Названия направлений в таблице архивов
    @c=();
    $p=&sql_select_line($dbh,"SELECT * FROM arch_trafnames WHERE mon=$Fmon AND year=".($Fyear+1900)." AND preset=0 LIMIT 1",'Названия направлений за указанный месяц/год');
    if( $p )
    {
       $c[$_]=$p->{"traf$_"}||"Направление $_" foreach (1..8);
    }else
    {
       $c[$_]="Направление $_" foreach (1..8);
    }
    $max_day=&GetMaxDayInMonth($Fmon,$Fyear);
 }

 $day=$Fday || $max_day;

 $url="$a&c=1&mid=$Fmid&day=$Fday&mon=$Fmon&year=$Fyear&class=$Fclass&sort=$Fsort";
 $url.="&g$_=1" foreach (split /,/,$grp_sel);

 $select_class='<br><select name=class size=8>';
 $select_class.="<option value=$_".($Fclass==$_ && ' selected').">$c[$_] трафик</option>" foreach (1..8);
 $select_class.='</select>';
 $form=&form('!'=>1,'#'=>1,'c'=>1,'mid'=>$Fmid,&div('cntr',"$mon_list $list_year ".&submit_a('Показать')).$select_class.$br2.$out_left);
 $out_left=&MessX($br.&bold('Суточная статистика трафика'.(!!$Fmid && " записи $ipp").' по нулевому пресету'.$br2).$form);

 $sum1=$sum2=0;
 $mon=$Fmon-1;

 if( $Fmid || $Fday )
 {
    $select='t.mid,u.name,u.ip,';
    $orderby=$Fsort? 'ORDER BY SUM(`out`) DESC' : 'ORDER BY SUM(`in`) DESC';
 }
  elsif ($grp_sel ne '')
 {
    $select=$orderby='';
 }
  else
 {
    $OUT.=&MessX('Выберите группы клиентов, для которых необходимо предоставить статистику:'.$br2.$form);
    return;
 }

 @head_buttons=$Fmid? ('К клиенту, Мб','От клиента, Мб') : (&ahref("$url&sort=0",'К клиенту, Мб'),&ahref("$url&sort=1",'От клиента, Мб'));
 $out_tbl='';
 $day++;
 while( --$day )
 {
   $time1=timelocal(0,0,0,$day,$mon,$Fyear);	# начало дня
   $time2=timelocal(59,59,23,$day,$mon,$Fyear);	# конец дня
   $time2++;

   $h=localtime($time1+1);
   $tbl_name='t'.(1900+$h->year).'x'.(1+$h->mon).'x'.$h->mday;

   if( !$tbl_is{$tbl_name} )
   {
      $out_tbl.=&RRow('*','c3',$day,'Нет данных за текущий день');
      $Fday && last;
      next;
   }

   $sql = "SELECT $select SUM(t.`in`) AS a,SUM(t.`out`) AS b FROM $tbl_name t LEFT JOIN user_select u ON t.mid=u.id WHERE t.class=$Fclass $where $orderby";
   $sth = &sql($dbs,$sql);
   while( $p=$sth->fetchrow_hashref )
   {
      $client=$select? &ShowClient($p->{mid},$p->{name},$p->{ip}) : 'сеть';
      $in=$p->{a};
      $out=$p->{b};
      $sum1+=$in;
      $sum2+=$out;
      $in=$in/$mb;
      $out=$out/$mb;
      $in=$in>10? &split_n(int $in) : $in>0.1? sprintf("%.3f",$in) : sprintf("%.6f",$in);
      $out=$out>10? &split_n(int $out) : $out>0.1? sprintf("%.3f",$out) : sprintf("%.6f",$out);
      $out_tbl.=&RRow('*','clrr',$Fday? $day : &div('nav2',&ahref("$url&day=$day",$day)),$client,$in,$out);
   }
   $Fday && last;
 }

 $out_tbl.=&RRow('head','Rrr',$br.'Сумма'.$br2,&bold(&split_n(int $sum1/$mb)),&bold(&split_n(int $sum2/$mb))) if !$Fday;
 $out_tbl=&Table('tbg1',&RRow('head','cccc',$br.'День'.$br2,'Клиент',@head_buttons).$out_tbl);
 $OUT.=&Table('',&RRow('','tt',$out_left,$out_tbl));
}

# ------------------------------------
#	Общая статистика трафика
# ------------------------------------
sub v_stat
{
 &DB2_Connect;
 $t_srez = $Fwhen || $ses::t; # если срез не запрошен, то считаем что заказан текущий
 $Fed = int $F{ed}; # единица измерения
 my $url = $Url->new(c=>$Fc, ed=>$Fed, when=>$Fwhen);
 $a.="&c=$Fc&ed=$Fed&when=$Fwhen";
 $Flast_time=$F{last_time};
 $tm=localtime($t_srez);
 $tname='v'.(1900+$tm->year).'x'.(1+$tm->mon).'x'.$tm->mday; # имя таблицы
 $base_time=timelocal(0,0,0,$tm->mday,$tm->mon,$tm->year);

 $right_col='';
 if( $Fmid )
 {
    ($userinfo,$grp,$mId,$allId,$alias_count,$aliases)=&GetUserInfo2($Fmid,$a);
    $url->{mid} = $Fmid;
    $a.="&mid=$Fmid";
    $where="mid=$Fmid";
    if( $alias_count )
    {
       if( $Falias )
       {
          $url->{alias} = 1;
          $a.="&alias=1";
          $where="mid IN ($allId)";
          $right_col.=&div('borderblue row1 lft',&bold('Суммарная статистика для' ).$aliases).$br;
       }else
       {
          $right_col.=&div('nav3 modified',&ahref("$a&alias=1",'Показать суммарную статистику всех учетных записей клиента')).$br.
              &div('borderblue row1 lft',"Статистика показана для учетной записи:<br>$userinfo<br>Обратите внимание: у текущей записи есть дополнительные записи (алиасы). ".
              "Статистика ведется на каждый алиас отдельно: $aliases".$br2).$br;
       }
    }else
    {
       $right_col.='Статистика показана для учетной записи:'.$br.$userinfo;
    }

    $where="WHERE $where";
    $sql="SELECT time,SUM(flows_in),SUM(flows_out),SUM(flows_reg),SUM(bytes),SUM(bytes_reg),detail FROM $tname $where GROUP BY time ORDER BY time DESC";
 }else
 {
    $where='';
    $sql="SELECT time,SUM(flows_in),SUM(flows_out),SUM(flows_reg),SUM(bytes),SUM(bytes_reg) FROM $tname GROUP BY time ORDER BY time DESC";
 }

 $max_bytes=1;
 $ed=$Fed>3? 'байт' : $Fed>2? 'КБ' : $Fed>1? 'КБ' : $Fed? 'МБ' : 'МБ';

 # $dbs !!!!
 my($sql,$page_buttons,$rows,$db) = Show_navigate_list($sql,$F{start},$Max_line_chanal,$url);

 $OUT.="<table class='tbg width100'>";
 $OUT.=&RRow('head nav','7c','Общая статистика трафика','') if !$Fmid;
 $page_buttons&&=&RRow('head',8,$page_buttons);
 $OUT.=$page_buttons;
 # <br> добавляю чтобы колонки были Уже т.к в соседних колонках трафик может wrap
 $OUT.=&RRow('head','cccccccc','Детализация','Время','График',"Общий трафик, $ed","Начисленный трафик, $ed",'Общее<br>количество<br>входящих<br>потоков','Общее<br>количество<br>исходящих<br>потоков','Количество<br>детализированных<br>потоков');

 $nb='&nbsp;&nbsp;';
 @out=();
 while( my %p = $db->get_line )
 {
    my $p = \%p;
    $tt=$p->{time}+$base_time;
    $show_tm=&the_hour($tt);
    $show_tm=&bold($show_tm) if $tt==$Flast_time;
    @fields=();
    foreach $i ('SUM(bytes)','SUM(bytes_reg)')
    {
       $h=$p->{$i};
       $h=$Fed>3? &split_n($h) : $Fed>2? &split_n(int $h/$kb) : $Fed>1? sprintf("%.3f",$h/$kb) : $Fed? &split_n(int $h/$mb) : sprintf("%.3f",$h/$mb);
       push @fields,$h.$nb;
    }
    $h=&ahref("$scrpt&graf=0&class=0&when=$tt&alias=$Falias&mid=$Fmid",'показать');
    $detail=!$Fmid? $h : $p->{detail}>1? $h.$br.'<span class=error>превышение потоков</span>' : $p->{detail}? $h : '<span class=disabled>выключена</span>';
    $bytes=$p->{'SUM(bytes)'};
    $max_bytes=$bytes if $max_bytes<$bytes;
    push @out,($bytes,$detail,$show_tm,@fields,$p->{'SUM(flows_in)'}.$nb,$p->{'SUM(flows_out)'}.$nb,$p->{'SUM(flows_reg)'}.$nb);
 }

 while( $graf=shift @out )
 {
    $graf="<img src='$img_dir/fon1.gif' width=".int($graf*$pix_for_traf/$max_bytes)." height=11>";
    $OUT.=&RRow('*','cclrrrrr',shift @out,shift @out,$graf,shift @out,shift @out,shift @out,shift @out,shift @out);
 }

 $OUT.=$page_buttons.'</table>'.$br;

 $OUT.="</td><$tc valign=top width=17%>".
   &Table('nav3',
     &RRow('row3','ll',&ahref("$a&ed=1",'целые Мбайт'),&ahref("$a&ed=0",'Мбайт')).
     &RRow('row3','ll',&ahref("$a&ed=3",'целые кбайт'),&ahref("$a&ed=2",'кбайт')).
     &RRow('row3','ll',&ahref("$a&ed=4",'байт'),'')
   ).$br.
   $right_col.
   &Get_list_of_stat_days($dbs,'v',"$a&when=",$t_srez);
}


# ---------------------------------
#  Статистика авторизации клиентов
# ---------------------------------
sub auth_stat
{
 $Adm->{pr}{106} or &Error("Нет прав на мониторинг системы.",$tend);

 $t_srez=$Fwhen || $ses::t;
 $a.="&c=$Fc&when=$Fwhen";
 $Fdetail=int $F{detail};
 if( $Fdetail )
 {
    $a.='&detail=1';
    %U=();
    $sth=&sql($dbh,"SELECT id,name,ip FROM users");
    while ($p=$sth->fetchrow_hashref)
    {
       ($id,$name,$ipp)=&Get_fields('id','name','ip');
       $U{$id}="$name ($ipp)";
    }
 }

 $_=localtime($t_srez);
 $time1=timelocal(0,0,0,$_->mday,$_->mon,$_->year);	# начало дня
 $time2=timelocal(59,59,23,$_->mday,$_->mon,$_->year);	# конец дня
 $i=10;
 $outl='Первая колонка - группа, 2-я - количество клиентов, авторизовавшихся в выбранный день указанным методом авторизации.<table><tr>';
 foreach $auth_method ('Авторизатор','На порту','Web-авторизация','PPPoE')
 {
    $grp=0;
    %sum=();
    $sql="SELECT COUNT(l.mid),u.grp,u.id FROM login l LEFT JOIN users u ON l.mid=u.id WHERE l.time>=$time1 AND l.time<=$time2 AND l.act>=$i AND l.act<=($i+9) AND u.id IS NOT NULL GROUP BY l.mid ORDER BY u.grp";
    $sth=&sql($dbh,$sql);
    while ($p=$sth->fetchrow_hashref)
    {
      ($id,$g,$n)=&Get_fields('id','grp','COUNT(l.mid)');
      $sum{$g}+=1;
      if( $Fdetail )
      {
         $out.=&RRow('*','ll', $Url->a($U{$id}, a=>'user', id=>$id),$n);
      }
    }

    $out=&RRow('head','C','Метод авторизации: '.&bold($auth_method));
    foreach my $g( sort{$Ugrp->{$b}{name} cmp $Ugrp->{$a}{name}} keys %$Ugrp )
    {
       $out.=&RRow('*','ll',$Ugrp->{$g}{name},$sum{$g});
    }
    $outl.='<td valign=top>'.&Table('tbg3',$out).'</td>';
    $i+=10;
 }
 $outl.='</tr></table>';

 $outr=$Fdetail? &CenterA("$a&detail=0",'Убрать детализацию') : &CenterA("$a&detail=1",'Детальнее');
 $outr.=&Get_list_of_login_days("$a&when=",$t_srez);
 $OUT.=&Table('width100',&RRow('','tt',$outl,$outr));
}

1;
