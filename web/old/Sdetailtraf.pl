#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
&TS_init;

$preset=$U{$Mid}{preset};
# список направлений, которые имеют названия. Если у направления нет названия, а трафик есть - проблемы в настройках
# и это обнаружится при посуточном просмотре статистики
$out=join '',map{ &ahref("$scrpt&when=$when&class=$_",$c[$_]).$br if $_==1 || $PresetName{$preset}{$_} } (1..8);

$DOC->{menu_left} .= div('cntr',&Mess3('row2','Направления:'.$br2.$out).&Get_list_of_stat_days($dbs,'x',"$scrpt&class=$class&when=",$when));

sub TS_init
{
 &Connect_DB2;
 $when=int $F{when} || $t;
 $class=int $F{class};
 $class=1 if $class<1 || $class>8;
}
 
sub go
{
 &TS_init;
 $detail=$Show_detail_traf? int $F{detail} : 0;
 $scrpt.="&when=$when&class=$class";
 $tm=localtime($when);
 $day=$tm->mday;
 $mon=$tm->mon;
 $year=$tm->year;
 $year_full=$year+1900;
 $mon++;
 $tname=$year_full.'x'.$mon.'x'.$day;	# часть имени таблицы для трафика запрошенного дня
 $h="на $day ".('','января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря')[$mon]." $year_full";

 $sql="SELECT SUM(`in`) AS a ,SUM(`out`) AS b,time FROM x$tname WHERE mid IN ($Sel_id) AND class=$class AND (`in`>0 OR `OUT`>0) GROUP BY time ORDER BY time DESC";
 ($sql,$page_buttons,$rows,$sth)=&Show_navigate_list($sql,$start,30,$scrpt,$dbs);
 unless ($rows)
   {
    &Message("$h статистика отсутствует. Выберите слева в меню день, на который хотите просмотреть статистику.");
    return;
   }
 $page_buttons&&=&RRow('head',4,$page_buttons);

 $out='';   
 while ($p=$sth->fetchrow_hashref)
   {
    ($t1,$t2,$time)=($p->{a},$p->{b},$p->{time});
    $ahref = $Show_detail_traf? &ahref("$scrpt&detail=$time",'&rarr;') : '';
    $ahref .= $ses::adm_url->a('adm', a=>'chanal', class=>0, when=>$time, alias=>$Falias, mid=>$id) if $Adm->{id} && $PR{112};
    $out .= RRow('*','crrc',
       the_hour($time),
       $t1? sprintf("%.3f",$t1/$kb):'&nbsp;',
       $t2? sprintf("%.3f",$t2/$kb):'&nbsp;',
       $ahref
    );
    next if $time!=$detail;
    $tm=localtime($time);
    $time-=timelocal(0,0,0,$tm->mday,$tm->mon,$tm->year); # время от начало суток
    $sth2=&sql($dbs,"SELECT INET_NTOA(ip) AS addr,bytes,direction FROM z$tname WHERE time=$time AND mid IN ($Sel_id) ORDER BY bytes DESC");
    while ($h=$sth2->fetchrow_hashref)
      {
       $out.=&RRow('*','lrrr',
          '',
          &Printf('[span big]',$h->{direction}? '&rarr;' : '&larr;'),
          $h->{addr},
          &split_n($h->{bytes})
       );
      }
   }

 $n='&nbsp;' x 2;
 $OUT.=&Table('tbg1 nav',
   &RRow('head',4,($For_U? "Показана статистика для $For_U" : 'Показана суммарная статистика для всех ваших ip').$br."$c[$class] трафик $h").
   $page_buttons.
   &RRow('tablebg','cccl','Время',$n.'Входящий трафик, Кб'.$n,$n.'Исходящий трафик, Кб'.$n,'').
   $out.
   $page_buttons
 );
}

1;      
