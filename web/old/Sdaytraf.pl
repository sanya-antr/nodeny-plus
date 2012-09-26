#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
sub go
{
 Connect_DB2();

 $sday=int $F{sday};
 $eday=int $F{eday};
 $mon=int $F{mon} || $mon_now;
 $year=int $F{year} || $year_now;
 $year_full=$year+1900;

 $mon_list = Set_mon_in_list($mon);
 $year_list = Set_year_in_list($year);

 $Fed=int $F{ed};
 $scrpt.="&sday=$sday&eday=$eday&mon=$mon&year=$year&ed=$Fed";

 $out=&bold_br('Этот раздел доступен только администраторам.').
   ($For_U? "Статистику для учетной записи ".&bold($For_U) : 'Суммарную статистику для всех учетных записей клиента').$br2.
   &form('!'=>1,'#'=>1,'ed'=>$Fed,'alias'=>$Falias,
     &table(' с '.v::input_t('sday',$sday,3,4,' autocomplete="off"').
       ' по '.v::input_t('eday',$eday,3,4,' autocomplete="off"').
       " за $mon_list $year_list ",&submit_a('показать'))
   );
 
 unless (defined $F{mon})
   {
    $OUT.=&MessX($out);
    return;
   }

 $out.=$br.
   &div('nav',
     &table(
        &ahref("$scrpt&ed=4",'Байт'),
        &ahref("$scrpt&ed=3",'целые Кб'),
        &ahref("$scrpt&ed=2",'Кб'),
        &ahref("$scrpt&ed=1",'целые Мб'),
        &ahref("$scrpt&ed=0",'Мб')
     ),1
   ).&bold('Сейчас данные отображаются в '.(('Мегабайтах','целых Мегабайтах','Килобайтах','целых Килобайтах','байтах')[$Fed]||'Мб'));

 if ($mon_now==$mon && $year_now==$year)
   {# запрошен трафик текущего месяца
    $p=$U{$Mid}{preset};
    $c[$_]=$PresetName{$p}{$_} || "Напр. $_" foreach (1..8);
    $eday||=$day_now;
   }
    else
   {# запрошен трафик предыдущих месяцев, берем названия направлений из архивов
    $p=&sql_select_line($dbh,"SELECT * FROM arch_trafnames WHERE year=$year_full AND mon=$mon AND preset IN ".
                             "(SELECT preset FROM arch_users WHERE uid=$Mid AND year=$year_full AND mon=$mon)");
    if ($p)
      {
       $c[$_]=$p->{"traf$_"}||"Напр. $_" foreach (1..8);
      }
       else
      {
       $OUT.=&Center_Mess('В архивах нет информации о том какие направления были в тарифном плане клиента, поэтому направления нумеруются с 1 по 8');
       $c[$_]="Напр. $_" foreach (1..8);
      }
   }

 $day=&GetMaxDayInMonth($mon,$year); # Получим максимальный день в запрошенном месяце

 $sday=$sday>$day? $day : $sday<1? 1 : $sday;
 $day=$eday if $eday>0 && $eday<$day;
 $tname=$year_full.'x'.$mon.'x';
 @sum_cells=();
 $tbl="<tr class=head><td>&nbsp;</td>";
 $tbl.="<$tcc>$c[$_]</td>" foreach (1..8);
 $tbl.="</tr><tr class=head><$tc>День</td>".("<$tc>Принял</td><$tc>Отправил</td>" x 8).'</tr>';
 $day++;
 while (--$day>=$sday)
   {
    @cells=();
    $tbl.=&PRow."<$tc>$day</td>";
    # есть ли статистика за данный день в агрегированной таблице 's'
    $p=&sql_select_line($dbs,"SELECT class FROM s$tname$day LIMIT 1");
    $h='s';
    unless ($p)
      {# есть ли статистика за данный день в таблице 'x'
       $p=&sql_select_line($dbs,"SELECT class FROM x$tname$day LIMIT 1");
       unless ($p)
         {
          $tbl.='<td colspan=16 class=disabled>Нет данных по трафику за этот день</td></tr>';
          next;
         }
       $h='x';
      }
    $sth=&sql($dbs,"SELECT class,SUM(`in`) AS a,SUM(`out`) AS b FROM $h$tname$day WHERE mid IN ($Sel_id) GROUP BY class");
    while ($p=$sth->fetchrow_hashref)
      {
       $_=$p->{class}*2;
       next unless $_; # когда нет ни одной строки в этот день, то будет возвращен null
       $cells[$_-2]=$p->{a};
       $cells[$_-1]=$p->{b};
      }
    foreach (0..15) 
      {
       $sum_cells[$_]+=$cells[$_];
       $tbl.=&DT_Print_traf($cells[$_]);
      }
    $tbl.='</tr>';
   }

 $tbl.="<tr class=head><$td>Сумма в выбранные дни</td>";
 $tbl.=&DT_Print_traf($sum_cells[$_]) foreach (0..15);
 $tbl.='</tr>';

 $OUT.=&MessX($out,0,1).&Table('tbg1',$tbl);
}

sub DT_Print_traf
 {# возвращает трафик в указанных единицах измерения
  # 4-'байт' : 3-'int КБ' : 2-'float КБ' : 1-'int МБ' : 0-'float МБ' ;
  my ($traf)=@_;
  return ($Fed==4? "<$td nowrap>":"<$td>").
    (!$traf? '&nbsp;' :
    $Fed==4? &split_n($traf) :
    $Fed==3? ($traf>=$kb? &split_n(int $traf/$kb) : '<span class=disabled>&lt; 1</span>'):
    $Fed==2? sprintf("%.3f",$traf/$kb) :
    $Fed==1? ($traf>=$mb? &split_n(int $traf/$mb) : '<span class=disabled>&lt; 1</span>') :
    ($traf/$mb>=0.001)? sprintf("%.3f",$traf/$mb) : '<span class=disabled>&lt; 0.001</span>').
  '</td>';
 }

1;      
