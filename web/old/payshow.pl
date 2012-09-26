#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

sub Table { return("<table class='$_[0]'>$_[1]</table>") }

my $r1 = 'row2';
my $r2 = 'row1';

sub PRow
{
 ($r1,$r2) = ($r2,$r1);
 return "<tr class=$r1>";
}
sub RRow
{
 local $_=shift;
 my %f = (
   'c' => "<$tc>",
   'l' => "<$tl>",
   'r' => "<$td>",
   'C' => "<$tc colspan='2'>",
   'L' => "<$tl colspan='2'>",
   'R' => "<$td colspan='2'>",
   '2' => "<$tc colspan='2'>",
   '3' => "<$tc colspan='3'>",
   '4' => "<$tc colspan='4'>",
   '5' => "<$tc colspan='5'>",
   '6' => "<$tc colspan='6'>",
   '7' => "<$tc colspan='7'>",
   '8' => "<$tc colspan='8'>",
   '9' => "<$tc colspan='9'>",
   '0' => "<$tc colspan='10'>",
   't' => "<$tc valign='top'>",
   'T' => "<$tc colspan='2' valign='top'>",
   '^' => "<$tl valign='top'>",
   'E' => "<$tl colspan='3'>",
   ' ' => "<td>"
 );
 my $out = s|^\*||? ($_? "<tr class='$_'>" : '<tr>' ) :
    /^</? $_ :
    $_ eq 'tablebg'? "<tr class='$_'>" :
    $_? "<tr class='$_'>" : '<tr>';
 $out.=($f{$_}||'<td>').(shift(@_)||'&nbsp').'</td>' foreach (split //,shift);
 return ($out.'</tr>');
}
sub CenterA
{
 return Center( div('nav',ahref(@_)) );
}
sub ahref
{
 return "<a href='$_[0]'".($_[2]? " $_[2]":'').">$_[1]</a>";
}

# Конвертация хеша (имя => значение) в "&имя=значение&имя=значение". Значения фильтруются &Filtr_out
# Вход: ссылка на хеш
sub Post_To_Get
{
 my ($a,$b,$c)=($_[0],'','');
 $b.='&'.v::filtr($c) while ($c=join '=',each(%$a));
 return $b;
}
# Формирование url-а на данные клиента
# Вход:
#  1 - id
#  2 - отображаемая в ссылке строка, например логин

sub ShowClient
{
 return ("<a href='$scrpt&a=user&id=$_[0]'>".v::filtr($_[1]).'</a>');
}

require "$cfg::dir_web/paystype.pl";

$Fuid = int $F{uid};
$Fyear = int $F{year};
$Fmon = int $F{mon};
$Fday = int $F{day};
$Fact=$F{act};

Show "<table class=width100><tr><td>&nbsp;&nbsp;</td><$tc valign=top width=80%>";
$tend='</td></tr></table>';

$AddRightBlock='';		# блок, который будет выводиться справа вверху меню, за которым идут
@AddRightBlock=();		# элементы блока <ul>...</ul>
@AddRightUrls=();

#  фильтр	расшифровка	привилегия	дополнительные hidden-поля для формы
@filtrs=(
   ['pays',	'нал',		1,	''],
   ['bonus',	'безнал',	1,	''],
   ['temp',	'врем.платежи',	1,	''],
   ['autopays',	'автоплатежи',	1,	''],
   ['mess',	'сообщения',	1,	''],
   ['mess2all',	'многоадресные сообщения',	1,	''],
   ['event',	'события',	14,	''],
   ['net',	'затраты сети',	1,	''],
   ['transfer',	'передачи денег', 1,	''],
);

%subs=(
 'pay'		=> \&f_pay,
 'bonus'	=> \&f_bonus,
 'client'	=> \&f_client,
 'worker'	=> \&f_worker,
 'sworker'	=> \&f_worker,		# зарплата работника + работы
 'mess'		=> \&f_mess,		# сообщения
 'mess2all'	=> \&f_mess2all,	# сообщения всем
 'event'	=> \&f_event,		# события
 'temp'		=> \&f_temp,		# временные платежи
 'net'		=> \&f_net,		# затраты на сеть
 'transfer'	=> \&f_transfer,	# передачи наличных
 'zarplata'	=> \&f_zarplata,	# зарплаты
 'admin'	=> \&f_admin,		# платежи выбранного админа
 'adminall'	=> \&f_admin,
 'category'	=> \&f_category,	# вывод платежей категории $F{category}
 'autopays'	=> \&f_autopays,	# автоплатежи
);

$Fnodeny=defined $subs{$F{nodeny}}? $F{nodeny} : $Fuid>0? 'client' : $Fuid? 'worker' : 'pay';

%subs2=(
 'list_admins'		=> \&list_admins,
 'zarplata'		=> \&zarplata,
 'list_categories'	=> \&list_categories,
);

&{ $subs2{$Fact} } if defined $subs2{$Fact};

%form_fields=('nodeny' => $Fnodeny);


if( $Fyear && $Fmon>0 )
{  # указан месяц на который предоставить отчет
   $year = $Fyear;
   $month=$Fmon;
   $form_fields{year} = $Fyear;
   $form_fields{mon} = $Fmon;
   $h=('','январь','февраль','март','апрель','май','июнь','июль','август','сентябрь','октябрь','ноябрь','декабрь')[$Fmon].' '.$year;
}else
{# иначе отчет для текущего месяца
   $year = $ses::year_now;
   $month = $ses::mon_now;
   $h='';
}

if( $Fday )
{
   $max_day=&GetMaxDayInMonth($month,$year-1900);		# получим количество дней в запрошенном месяце
   $month--;
   $Fday=$max_day if $Fday>$max_day || $Fday<1;
   $time1=timelocal(0,0,0,$Fday,$month,$year-1900);		# начало дня
   $time2=timelocal(59,59,23,$Fday,$month,$year-1900);	# конец дня
   $time2++;
   $form_fields{day}=$Fday;
   $h="$Fday число, $h";
}else
{
   $month--;
   $time1=timelocal(0,0,0,1,$month,$year-1900); #  начало месяца
   if ($month<11) {$month++} else {$month=0; $year++}
   $time2=timelocal(0,0,0,1,$month,$year-1900); #  начало следущего месяца
}

push @AddRightBlock,"За $h" if $h;

# Получим список админов
Adm->get();
$A = $Adm::adm;

# Список клиентов или данные клиента, по платежам которого фильтр. (Выше в %subs не должно меняться название ключа 'client')
$sth = Db->sql("SELECT id,mid,grp,name FROM users".($Fnodeny eq 'client' && " WHERE id=$Fuid"));
while( my %p = $sth->line )
{
   $id = $p{id};
   $user{$id}{$_} = $p{$_} foreach('mid','grp','name');
}

$W = {};	# Массив работников
$Allow_worker='';	# Cписок id работников, которые в том же отделе, что и админ
foreach (keys %$W)
{
   $Allow_worker.="-$_,"; # поставим минус перед id работника, так как в платежах они с минусом
}
chop $Allow_worker;	# Уберем последнюю запятую

$SqlS="FROM pays p LEFT JOIN users u ON u.id=p.mid WHERE ";

# В $allow_grp получим список групп, к которым есть полный доступ. В $allow_grp_alt список груп в виде "(u.grp>5 AND u.grp<=10) OR ..." - 
# может получится короче чем $allow_grp. Опасности в том, что не перечислены строго существующие группы - нет, т.к. если в таблице pays
# будет запись в несуществующй группе, то она отобразится как недоступная
$allow_grp=$allow_grp_alt=$allow_grp_sel=$for_grp='';
$min_grp=0;
$max_grp=-1;
foreach( sort{ $a <=> $b } keys %{ Ugrp->hash })
{  # обработка в порядке возрастания номеров групп
   if( !Adm->chk_usr_grp($_) )
   {
      next if $max_grp<0;
      $allow_grp_alt.=' OR ' if $allow_grp_alt;
      $allow_grp_alt.=$min_grp!=$max_grp? "(u.grp>=$min_grp AND u.grp<=$max_grp)" : "u.grp=$min_grp";
      $min_grp=0;
      $max_grp=-1;
      next;
   }
   if( $F{"g$_"} )
   {
      $allow_grp_sel.="$_,";
      $form_fields{"g$_"}=1;
      $for_grp.=$br.Ugrp->($_)->{name};
   }
   $allow_grp.="$_,";
   $min_grp||=$_;
   $max_grp=$_;
}
chop $allow_grp;
chop $allow_grp_sel;

push @AddRightBlock,"Для групп:$for_grp" if $for_grp;

$allow_grp=$allow_grp_sel if $allow_grp_sel; # админ указал группы клиентов

$allow_grp='-1' if $allow_grp eq ''; # нельзя $allow_grp||='-1' т.к. $allow_grp может быть = '0'

if( $max_grp>=0 )
{
   $allow_grp_alt.=' OR ' if $allow_grp_alt;
   $allow_grp_alt.=$min_grp!=$max_grp? "(u.grp>=$min_grp AND u.grp<=$max_grp)" : "u.grp=$min_grp";
} 
$allow_grp_alt||='0'; # здесь 0 выступает как условие false, далее в sql получим: (0 OR u.grp IS NULL)

$SqlC='('.(length($allow_grp)<length($allow_grp_alt) || $allow_grp_sel? "u.grp IN ($allow_grp)" : $allow_grp_alt).' OR u.grp IS NULL) AND ';

$header_tbl='';
$header='';

@cols=('Клиент',"Приход,&nbsp;$gr","Расход,&nbsp;$gr",'Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
@cols_map=(1,1,1,1,1,1,1,1);

&{ $subs{$Fnodeny} };

sub access_grp
{
 return;
}

sub access_admin
{
 return if Adm->chk_privil('other_adm_pays');
 $SqlC.=" AND p.creator_id=".Adm->id;
 push @AddRightBlock,"Только ваши записи";
}

sub what_cash
{
 return if $F{scash} eq '';
 $F{scash}+=0;
 if( $F{ecash} ne '' )
 {
    $F{ecash}+=0;
    ($F{scash},$F{ecash})=($F{ecash},$F{scash}) if $F{scash}>$F{ecash};
    push @AddRightBlock,"Сумма платежа в диапазоне:<br><b>$F{scash}</b> .. <b>$F{ecash}</b> $gr";
    $SqlC.=" AND p.cash>=$F{scash} AND p.cash<=$F{ecash}";
    $form_fields{ecash}=$F{ecash};
    $form_fields{scash}=$F{scash};
 }else
 {
    push @AddRightBlock,"Сумма платежа <b>$F{scash}</b> $gr";
    $SqlC.=" AND p.cash=$F{scash}";
    $form_fields{scash}=$F{scash}; # не переноси до условия т.к. в блоке выше может быть обмен scash и ecash
 }
}

sub f_client
{# платежи клиента
 Error("Клиент id=$Fuid не найден в базе данных, только суперадмин может просмотреть записи, ".
    "отсутствующего в базе данных, клиента.",$tend) if $Fuid<=0 || (!defined($user{$Fuid}{grp}) && !Adm->chk_privil('SuperAdmin'));
 Error("Клиент находится в группе, доступ к которой вам ограничен.",$tend) if !Adm->chk_usr_grp($user{$Fuid}{grp}) && !Adm->chk_privil('SuperAdmin');
    my $p = Get_usr_info($Fuid);
    $userinfo = $p->{full_info};
    $mId = $Fuid;
 $AddRightBlock.=$userinfo.$br;
 push @AddRightUrls,&ahref("$scrpt&a=pays&mid=$Fuid",'Провести платеж') if Adm->chk_privil(54) || Adm->chk_privil(56) || Adm->chk_privil(57);
 push @AddRightUrls,&ahref("$scrpt&a=pays&op=mess&mid=$Fuid",'Отправить сообщение') if Adm->chk_privil(55);
 $DontShowUserField=1;
 @cols=('&nbsp;',"Приход,&nbsp;$gr","Расход,&nbsp;$gr",'Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $form_fields{uid}=$Fuid;
 $SqlC="p.mid=$Fuid";
 &what_cash;
 $Ftype_pays=int $F{type_pays};
 %f=(
   10 => 'платежи',
   30 => 'собщения',
 -495 => 'замечания',
   50 => 'события',
 );
 $temp_url=$scrpt.&Post_To_Get(\%form_fields);
 if( $f{$Ftype_pays} )
 {
    $SqlC.=$Ftype_pays>0? " AND p.type=$Ftype_pays" : " AND p.category=".(-$Ftype_pays);
    push @AddRightUrls,&ahref($temp_url,'Показать всю историю клиента');
    $form_fields{type_pays}=$Ftype_pays;
    unshift @AddRightBlock,"Показаны $f{$Ftype_pays} клиента";
 }
  else
 {
    unshift @AddRightBlock, 'История клиента';
 }
 foreach (keys %f)
 {
    push @AddRightUrls,&ahref("$temp_url&type_pays=$_",'Показать '.$f{$_}) if $_!=$Ftype_pays;
 }
 # в менюшку фильтров (нал/безнал/события/работы) добавим фильтр
 push @filtrs,['client','историю клиента',1,v::input_h('uid'=>$Fuid)];
}

sub f_worker
{# зарплата работника
 Error("У вас нет прав доступа к статистике зарплат/авансов.");
 $wid=-$Fuid;
 if( defined $W->{$wid}{name} )
 {
    push @AddRightBlock,'Для работника '.v::bold($W->{$wid}{name});
 }
  else
 {
    &Error("Работник с id=$wid не найден в базе данных. Если есть записи зарплаты на этот id, то их может просмотреть админ с правами работы в разных отделах.",$tend)
 }
 $form_fields{uid}=$Fuid;
 $SqlC="p.mid=$Fuid";
 push @AddRightUrls,&ahref("$scrpt&a=oper&act=workers&op=edit&id=$wid",'Данные работника');
 if( $Fnodeny ne 'sworker' )
 {
    $SqlC.=" AND p.type=10";
    %temp_files=%form_fields;
    $temp_files{nodeny}='sworker';
    push @AddRightUrls,&ahref($scrpt.&Post_To_Get(\%temp_files),'Показать события работника');
 }
 $header_tbl="<$tc>Работник</td>";
}

sub f_mess
{
 unshift @AddRightBlock,'Сообщения и комментарии';
 $SqlC.='p.type=30';
 &access_grp;
 @cols=('Клиент','','Сообщение','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[3]=0;
}

sub f_mess2all
{
 Adm->chk_privil(34) or Error("Нет прав на просмотр групповых сообщений.",$tend);
 unshift @AddRightBlock,'Групповые сообщения';
 $SqlC='p.type=30 AND p.mid=0';
 @cols=('&nbsp;','Тип','Сообщение','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[3]=0;
}

sub f_event
{
 Adm->chk_privil('events') or Error("У вас нет прав на просмотр событий.",$tend);
 unshift @AddRightBlock,'События';
 $SqlC.="p.type=50 AND p.category NOT IN (460,461)"; # не включаем работы (460,461)
 &access_grp;
 @cols=('Клиент','Событите','Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[3]=0;
}

sub f_temp
{# временные платежи. Отдел проверять не надо поскольку идет проверка по группе клиента
 unshift @AddRightBlock,'Временные платежи';
 $SqlC.="p.type=20";
 &access_grp;
 &what_cash;
 @cols=('Клиент',"Платеж,&nbsp;$gr",'&nbsp','Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
}

sub f_net
{   
 unshift @AddRightBlock,'История вложений/затрат сети';
 $SqlC='p.type=10 AND ';
 $SqlC.='p.mid<=0';
 if( !Adm->chk_privil('other_adm_pays') )
 {
    $SqlC.=" AND p.creator_id=".Adm->id;
    push @AddRightBlock," (<span class=data1>только ваши платежи</span>)";
 }
 &what_cash;
 @cols=('&nbsp;',"Приход,&nbsp;$gr","Расход,&nbsp;$gr",'Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
}

sub f_zarplata
{
 Error("У вас нет прав для доступа к статистике по зарплатам/авансам");
}

sub f_transfer
{
 $SqlC='p.mid=0 AND p.type=40';
 $SqlC.=" AND (reason='".Adm->id."' OR comment='".Adm->id."')" unless Adm->chk_privil('other_adm_pays'); # нет прав на просмотр платежей других админов - выводим только передачи для текущего админа
 unshift @AddRightBlock,Adm->chk_privil('other_adm_pays')? 'Передачи наличности между администраторами' : 'Передачи наличности на вас или обратно';
 @cols=('&nbsp;',"Сумма,&nbsp;$gr",'Комментарий','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[3]=0;
}

sub f_admin
{# Платежи админа либо системы если $Fadmin==0
 $Fadmin=int $F{admin};
 Error("Ваши привилегии не позволяют просматривать платежи другого администратора",$tend)
    if !Adm->chk_usr_grp('other_adm_pays') && $Fadmin && $Fadmin!=Adm->id;

 $form_fields{admin}=$Fadmin;

 if( $Fadmin )
 {
    push @filtrs,['admin','администратора '.$A->{$Fadmin}{login},1,v::input_h('admin'=>$Fadmin)];

    if( $Fnodeny eq 'adminall' )
    {  # Более детальный отчет по админу
       my %p = Db->line("SELECT SUM(cash) FROM pays WHERE type=10 AND bonus='' AND creator_id=$Fadmin AND cash>0");
       $i1=%p? $p{'SUM(cash)'} : 0;

       my %p = Db->line("SELECT SUM(cash) FROM pays WHERE type=10 AND bonus='' AND creator_id=$Fadmin AND cash<0");
       $i2=%p? $p{'SUM(cash)'} : 0;
    }else
    {
       my %p = Db->line("SELECT SUM(cash) FROM pays WHERE type=10 AND bonus='' AND creator_id=$Fadmin");
       $i1=%p? $p{'SUM(cash)'} : 0;
       $i2=0;
    }

    my %p = Db->line("SELECT SUM(cash) FROM pays WHERE type=40 AND reason='$Fadmin'");
    $i3=%p? $p{'SUM(cash)'} : 0;

    my %p = Db->line("SELECT SUM(cash) FROM pays WHERE type=40 AND comment='$Fadmin'");
    $i4=%p? $p{'SUM(cash)'} : 0;

    my %p = Db->line("SELECT SUM(money) FROM cards WHERE adm_owner=$Fadmin AND alive IN('stock','good')");
    $i5=%p? $p{'SUM(money)'} : 0;

    $Na_rukax=$i1+$i2-$i3+$i4;

    unshift @AddRightBlock,'История платежей администратора '.v::bold($A->{$Fadmin}{login}||'<span class=error>отсутствующего в базе данных</span>');
 }
  else
 {
    unshift @AddRightBlock,'История системных событий';
 }

 $u1=$Fadmin? "(p.type=40 AND (p.reason='$Fadmin' OR p.comment='$Fadmin'))" : '0'; # условие передачи наличных
 $u2="p.creator_id=$Fadmin"; # условия платежей админа
 if( $Fnodeny eq 'adminall' )
 {  # События можно выводить?
    $u2=!Adm->chk_privil('events')? "($u2 AND p.type IN (10,20,40))" : $Fadmin? $u2 : "($u2 AND p.type IN (10,20,40,50))"; # не выводим сообщения при просмотре админа "система"
    $header.=&Table('tbg1',
        &RRow('*','lrl','Принял наличных',v::bold(split_n(int $i1)),$gr).
        &RRow('*','lrl','Вернул наличных',v::bold(split_n(int -$i2)),$gr).
        &RRow('*','lrl','Получил от других администраторов наличных',v::bold(split_n(int $i4)),$gr).
        &RRow('*','lrl','Передал другим администраторам наличных',v::bold(split_n(int $i3)),$gr).
        &RRow('head','lrl','На руках',v::bold(split_n(int $Na_rukax)),$gr).
        &RRow('*','lrl','Получил на реализацию карточек пополнения счета на сумму',v::bold(split_n(int $i5)),$gr).
        &RRow('head','lrl','На руках с учетом карточек пополнения',v::bold(split_n(int $Na_rukax+$i5)),$gr)) if $Fadmin;
 }
  else
 {   # выводим только платежи
     $u2="($u2 AND p.type=10)";
     push @AddRightUrls,&ahref("$scrpt&admin=$Fadmin&nodeny=adminall",'Детальнее');
 }
 # используем $Allow_grp,в который включены ограниченные группы - необходимо показывать, что есть скрытые записи
 $SqlC="(u.grp IN ($allow_grp) OR u.grp IS NULL) AND ($u1 OR $u2)";
 &what_cash;
}

sub f_category
{# вывод запрошенной категории платежей
 $Fcategory=int $F{category};
 $name_category=$Fcategory? 'категории '.v::commas($ct{$Fcategory} || "неизвестной с кодом $Fcategory") : 'без категории';
 unshift @AddRightBlock,"Платежи $name_category";
 $form_fields{category}=$Fcategory;
 $SqlC.="p.category";
 if( $Fcategory )
 {
    $SqlC.="=$Fcategory";
 }
  else
 {  # если категория не заказана, то выведем все несуществующие категории, а не только нулевую!
    $i=0;
    $SqlC.=" NOT IN (";
    # походу разрядим строку пробелами чтоб при выводе sql на страницу она не была километровой ширины
    $SqlC.="$_,".($i++%15? '':' ') foreach (keys %ct);
    chop $SqlC; # уберем последнюю запятую
    $SqlC.=") AND p.type=10";
 }
 &access_grp;
 &access_admin;
 push @filtrs,['category',$name_category,1,v::input_h('category'=>$Fcategory)];
}

sub f_autopays
{
 unshift @AddRightBlock,'Автоплатежи';
 $SqlC.="p.type=50 AND p.category=0";
 &access_grp;
 &what_cash;
 @cols=('Клиент','Автоплатеж','Дата,&nbsp;время','&nbsp;','Админ','&nbsp;');
 $cols_map[2]=0;
 $cols_map[3]=0
}

sub f_pay
{# обычные платежи
 unshift @AddRightBlock,'Платежи наличностью';
 $SqlC.="p.type=10 AND p.bonus=''";
 &access_grp;
 &access_admin;
 &what_cash;
}

sub f_bonus
{# безналичные платежи
 unshift @AddRightBlock,'Безналичные платежи';
 $SqlC.="p.type=10 AND p.bonus<>''";
 &access_grp;
 &access_admin;
 &what_cash;
}

if( $F{year} )
{
   $SqlC.=" AND p.time>$time1 AND p.time<$time2";
   %temp_files=%form_fields;
   delete $temp_files{year};
   delete $temp_files{mon};
   delete $temp_files{day};
   push @AddRightUrls,&ahref($scrpt.&Post_To_Get(\%temp_files),'Показать за все время');
}

$sql="SELECT p.*,u.name,u.grp $SqlS $SqlC ORDER BY p.time DESC";

if( $F{showgrp} )
{
   $form_fields{showgrp}=1;
   push @cols,'Группа';
   $cols_map[9]=1;
}
 else
{
   push @AddRightUrls,&ahref($scrpt.&Post_To_Get(\%form_fields).'&showgrp=1','Показать столбец '.v::commas('группа'));
} 

Show div('message',$header) if $header;

$cols=0;
$header_tbl='';
foreach (@cols)
{
   $header_tbl.="<$tc>$_</td>";
   $cols++;
}

if( Adm->chk_privil('edt_category_pays') )
{
   $submit_button="<tr><$tc colspan='$cols'>".$br.v::submit('Сохранить категории').$br.'</td></tr>';
   Show form_a('!'=>1,'a'=>'pays','act'=>'update_category','start'=>$F{start},%form_fields);
}

($sql,$page_buttons,$rows,$db) = Show_navigate_list($sql,$F{start},$cfg::Max_list_pays,$Url->new(%form_fields));

$nav=$page_buttons && "<tr class=tablebg><$tl colspan='$cols'>$page_buttons</td></tr>";
$header_tbl="<table class='td_wide width100'>$nav<thead><tr>$header_tbl</tr></thead>";
$br_line="<img src='$img_dir/fon1.gif' width=100% height=1>";
$t1='';
$n_pays=0;
undef $Na_rukax; # нельзя = 0 т.к. "на руках" может быть 0
%pay_types=(
 '10' => 'pay',
 '20' => 'temp',
 '30' => 'mess',
 '40' => 'transfer',
 '50' => 'event'
);

$out='';
sub Get_fields
{
 return map{$p->{$_} }(@_);
}
while( my %p = $db->line )
{
    $p = \%p;
   %f=();
   $f{$pay_types{$p->{type}}}=1;
   ($id,$mid,$cash,$bonus,$admin_id,$time,$r,$k,$category)=&Get_fields('id','mid','cash','bonus','creator_id','time','reason','comment','category');

   # Если нет прав на просмотр событий, то можно показывать:
   next if $f{event} && !Adm->chk_privil('events') &&
     $category!=410 &&	# изм.данных клиента
     $category!=411 &&	# создание нового клиента
     $category!=417 &&	# запрос на изменение
     $category!=460 &&	# задание работникам выполняется
     $category!=461;	# задание работникам выполнено

   $r=~s|\n$||;
   $k=~s|\n$||;
   $tt=&the_time($time);

   # $pay_group - группа, к которой относится платеж:
   # 0 - положительный безналичный платеж клиента
   # 1 - отрицательный безналичный платеж клиента (или нулевой - обязательно для нулевых снятий за услуги)
   # 2 - вложение в сеть
   # 3 - затраты на сеть
   # 4 - иные (событие, сообщение)
   # 6 - положительный платеж наличностью
   # 7 - отрицательный платеж наличностью
   # 9 - зарплата/аванс работнику
   if( $f{pay} )
   {
      $pay_group=!$mid? 2 : $mid<0? 8 : $bonus? 0 : 6;
      $pay_group++ if $cash<=0;
   }
    else
   {
      $pay_group=4;
   }

    if( $Fadmin )
    {  # для статистики по конкретному админу выведем кол-во наличных на конец каждого дня
        unless (defined $Na_rukax)
        {  # посчитаем наличность в данный момен времени
            my %h = Db->line("SELECT SUM(cash) AS cash FROM pays WHERE type=10 AND bonus='' AND creator_id=$Fadmin AND time<=$time");
            $Na_rukax=%h? $h{cash} : 0;
            my %h = Db->line("SELECT SUM(cash) AS cash FROM pays WHERE type=40 AND reason='$Fadmin' AND time<=$time");
            $Na_rukax -= $h{cash} if %h;
            my %h = Db->line("SELECT SUM(cash) AS cash FROM pays WHERE type=40 AND comment='$Fadmin' AND time<=$time");
            $Na_rukax += $h{cash} if %h;
        }
      $t2=$tt=~/^(.+?) .+$/? $1 : ''; # получим дату платежа в виде строки, учти, что формат привязан к &the_time
      $out.=&RRow('tablebg',$cols,&div('lft','На руках: '.v::bold(sprintf("%.2f",$Na_rukax))." $gr")) if $t1 ne $t2; # дата изменилась, выведем наличные на руках
      $t1=$t2;
      $Na_rukax-=$cash if $f{pay} && !$bonus;		# принял наличные
      $Na_rukax-=$cash if $f{transfer} && $k==$Fadmin;	# получил наличные от другого админа
      $Na_rukax+=$cash if $f{transfer} && $r==$Fadmin;	# передал наличные другому админу
    }

   $cash=sprintf("%.2f",$cash)+0; # не ранее подсчета $Na_rukax, чтобы не накапливалась погрешность

   if( $cash>0 )
   {
      $cash_left=$bonus? _('[span data1]', $cash) : v::bold($cash);
      $cash_right='';
      $colspan_cash=$f{transfer}? 1 : 0;
   }
    elsif ($cash<0)
   {
      $cash_left='';
      $cash_right=$bonus? _('[span error]', -$cash) : v::bold(-$cash);
      $colspan_cash=0;
   }
    else
   {
      $cash_left=$cash_right='';
      $colspan_cash=1;
   } 

   if( $mid>0 )
   {
        if( !Adm->chk_usr_grp($user{$mid}{grp}) && !Adm->chk_privil('SuperAdmin') )
        {  # Выведем, что запись недоступна т.к. если будет вывод по админу - будет казаться, что неправильно считаются деньги на его руках
            $out.=&RRow('disabled',$cols,"клиент в группе, к которой у вас нет доступа (id записи $id)");
            next;
        }
        # клиент (если права на просмотр ФИО нет, то при выводе логин заменим на id)
        $Clnt=!defined $user{$mid}{name}? '<span class=error>Удаленный клиент</span>' :
            ShowClient($mid,substr($user{$mid}{name},0,20),$mid);
   }
    elsif( $mid )
   {# зарплата/событие работника
      if( !Adm->chk_privil(110) )
      {
         $out.=&RRow('disabled',$cols,"недоступная вам запись id: $id");
         next;
      } 
      $wid=-$mid;
      $Clnt=$W->{$wid}{name}? _('[span data1]', 'работник').$br.&ahref("$scrpt&a=oper&act=workers&op=edit&id=$wid",$W->{$wid}{name}) :
        _('[span error]', 'неизвестный работник');
   }
    else
   {
      $Clnt=v::bold('Сеть');
   }

   $button2=''; # кнопка 'ответ дан'

   {
    if ($f{transfer})
    {  # передача наличных
       $reason="<span class='modified width100'>".v::bold($A->{$r}{login}||'<span class=error>неизвестный админ</span>').
         ' &rarr; '.v::bold($A->{$k}{login}||'<span class=error>неизвестный админ</span>').'</span>';
       $Clnt=&tag('span','Передача наличных','class=boldwarn');
       last;
    }

    if( $category_subs{$category} )
    {  # в данной категории есть расшифровка поля reason
       ($reason,undef,$dont_show_comment)=&{ $category_subs{$category} }($r,$k,$time,$mid);
    }else
    {
       $reason=$r!~/^\s*$/? $r : '';
       $dont_show_comment=0;
    }
    
    if( $f{mess} && ($category==491 || $category==492) )
    {  # сообщение к администрации
       $h="$scrpt&a=pays&op=mess&q=$id&mid=$mid";
       if ($category==491)
       {
          $reason=&tag('span','Сообщение от клиента:','class=data1').$br.$reason;
          $cash_left=Adm->chk_privil(55) && &CenterA($h,'Ответить');
          $button2=&ahref("$scrpt&a=pays&id=$id&act=markanswer",'О',"title='ответ дан'") if Adm->chk_privil('SuperAdmin');
       }else
       {
          $reason=v::bold('Сообщение от клиента:').$br.$reason;
          $cash_left=Adm->chk_privil(55) && &ahref($h,'Ответить повторно');
       }
    }

    $cash_left.='Событие' if $f{event};

    if( $k!~/^\s*$/ && !$dont_show_comment )
    {
       $reason.=$br.$br_line.$br if $reason; # разделительная линия
       $reason.=$k;
    }
   }

   $out.=&PRow.( $DontShowUserField? &tag('td','&nbsp;') : &tag('td',$Clnt,'class=nav3') );
   if ($colspan_cash && $cols_map[2] && $cols_map[3])
   {
      $out.=&tag('td',$cash_left,'colspan=2');
   }else
   { 
      $out.=&tag('td',$cash_left) if $cols_map[2];
      $out.=&tag('td',$cash_right) if $cols_map[3];
   } 
   $out.="<$tl>$reason</td><td class='disabled h_left'>$tt</td><$tc>";

   if( Adm->chk_privil('edt_category_pays') && $f{pay} )
   {
      $n_pays++;
      $_=$ct_category_select[$pay_group];
      $_.="<option value=$category selected>НЕДОПУСТИМАЯ КАТЕГОРИЯ: $category</option>" if $category &&
          !(s/<option value=$category>/<option value=$category selected>/);
      $out.="<select name=id_$id class=sml><option value=0>&nbsp;</option>$_</select>";
   }
    else
   {
      $out.=$ct{$category}||'&nbsp;';
   } 
   $out.="</td><$tc>";
   $out.=!$admin_id? '&nbsp;' : $admin_id==Adm->id? "<span class=data2>$A->{$admin_id}{login}</span>" : $A->{$admin_id}{login}||'???';
   $out.="</td><$tc class=nav3>";
   # если это не событие или разрешено работать с событиями
   $out.=!$f{event} || Adm->chk_privil('events')? &ahref("$scrpt&a=pays&act=show&id=$id",'&rarr;'):'&nbsp;';
   $out.=$button2;
   $out.="<$tl nowrap>".($mid? Ugrp->($user{$mid}{grp})->{name}  : '').'</td>' if $cols_map[9];
   $out.="</td></tr>";
}

if( $out )
{
   Show $header_tbl.$out;
   Show $submit_button if $n_pays;
   Show "$nav</table>";
}
 else
{
   $out='';
   $out.="<li>$h</li>" while ($h=shift @AddRightBlock);
   Show $br2.MessageBox('По фильтру:'.$br2.&tag('ul',$out).'записей не найдено');
}
Show '</form>' if Adm->chk_privil('edt_category_pays');
Show '</td>';

# =========================
# Правое навигационное меню
# =========================

Show "<$tc valign=top>";
$out='';
$out.="<li>$h</li>" while ($h=shift @AddRightBlock);
$AddRightBlock.='Фильтр:'.&tag('ul',$out) if $out;
$out='';
$out.="<li>$h</li>" while ($h=shift @AddRightUrls);
$AddRightBlock.='Операции:'.&tag('ul',$out) if $out;
Show MessageWideBox(div('lft',$AddRightBlock)) if $AddRightBlock;


$mon_list = Set_mon_in_list($Fmon||$ses::mon_now);
$h1="$mon_list <select size=1 name='year'>";
#$h1.="<option value=$_>$_</option>" foreach (100..);
$h1.="<option value=$_>$_</option>" foreach ($ses::year_now-5..$ses::year_now);
$h1.='</select>';
$year = $Fyear || $ses::year_now;
$h1 =~ s/=$year>/=$year selected>/;

$h2='<select size=1 name=day><option value=0>&nbsp;</option>';
$h2.="<option value=$_>$_</option>" foreach (1..31);
$h2.='</select>';
  
$out=&Center($h2.$h1.$br.'От '.v::input_t(name=>'scash',value=>$F{scash})." $gr до ".v::input_t(name=>'ecash',value=>$F{ecash})." $gr").$br;

$out1='';
foreach (@filtrs)
{
   ($x,$y,$z,$i)=@{$_};
   Adm->chk_privil($z) or next;
   $i=" $y$i$br";
   $Fnodeny eq $x? ($out.="<input type=radio name=nodeny value=$x checked>$i"): ($out1.="<input type=radio name=nodeny value=$x>$i");
} 

$out.=$br.v::submit('Показать').$br.
    url->a(['&darr; Дополнительно'], -base=>'#show_or_hide', -rel=>'my_x_grp');

$out2 = '';

$out.="<div class='my_x_grp' style='display:none'>$out1$br";

$out.="Для групп:$br2$out2</div>";

Show MessageWideBox( form('!'=>1,'#'=>1,$out) );

$out='';
#$out.=&ahref("$scrpt&a=multipays",'Мультиплатежи') if $Adm->{pr}{pays_create};
$out.=&ahref("$scrpt&a=pays",'Провести платеж сети') if Adm->chk_privil('net_pays_create');
$out.=&ahref("$scrpt&a=pays&act=mess2all",'Отправить многоадресное сообщение') if Adm->chk_privil('mess_all_usr');
$out.=&ahref("$scrpt&a=report",'Отчет') if Adm->chk_privil('fin_report');
$out.=&ahref("$scrpt&a=pays&act=send",'Передача наличных') if Adm->chk_privil('transfer_money');
$out.=&ahref("$scrpt&act=list_categories",'Категории платежей');
$out.=Adm->chk_privil('other_adm_pays')? &ahref("$scrpt&act=list_admins",'Администраторы') :
     &ahref("$scrpt&nodeny=admin&admin=".Adm->id,"Ваши платежи (".Adm->login.")");
$out.=&ahref("$scrpt&act=zarplata",'Работники');
$out.=&ahref("$scrpt&nodeny=adminall&admin=0",'Система');

Show div('nav2',MessageWideBox($out)).'</td></tr></table>';
&Exit;

# ------------------------------------
#	Вывод списка админов
# ------------------------------------
sub list_admins
{
 if( !Adm->chk_privil('other_adm_pays') )
 {  # нет прав на просмотр платежей другого админа, далее покажем платежи текущего админа
    $Fnodeny = 'admin';
    $F{admin} = Adm->id;
 }

 $last_office=-1;
 $r3=$r1;
 $r4=$r2;
 $i=1;
 $out='';
 $OUTL=$OUTR='';
 $sql="SELECT * FROM admin ORDER BY login";
 $sth= Db->sql($sql);
 $gg = 0;
 while( my %p = $sth->line )
 {
    if( !$gg++ )
    {
        $out.=$OUT1;
        $out.=&RRow('rowoff','C','Неактивные администраторы').$OUT2 if $OUT2;
        $out.='</table>';
        if ($i) {$OUTL.=$out} else {$OUTR.=$out}
        $i=1-$i;
        $out="<table class='width100'>";
        $OUT1=$OUT2='';
    } 

    $admin = $p{login} || '????';
    $name = v::filtr($p{name});

    $id=$p{id};
    $h="<$tl width='35%'>".ahref("$scrpt&nodeny=admin&year=$ses::year_now&mon=$ses::mon_now&admin=$id",$admin)."</td><$tl>$name</td></tr>";
    $privil=$p{privil}.',';
    if ($privil=~/,1,/) {$OUT1.="<tr class=$r1>$h"; ($r1,$r2)=($r2,$r1)} else {$OUT2.="<tr class=$r3>$h"; ($r3,$r4)=($r4,$r3)}
 }

 if( $out )
 {
    $out.=$OUT1;
    $out.=&RRow('rowoff','C','Неактивные администраторы').$OUT2 if $OUT2;
    $out.='</table>';
    if ($i) {$OUTL.=$out} else {$OUTR.=$out}
    $i=1-$i;
 } 

 $out='';         
 # Присутствующие в платежах, но отсутствующие в таблице админов
 $sth= Db->sql("SELECT DISTINCT creator_id FROM pays p LEFT JOIN admin a ON p.creator_id=a.id WHERE a.id IS NULL AND p.creator_id<>0");
 while( my %p = $sth->line )
 {
    $admin_id=$p{creator_id};
    $out.=&ahref("$scrpt&nodeny=admin&admin=$admin_id","Отсутствующий в базе админ с id: $admin_id");
 }

 $i? ($OUTL.=$out) : ($OUTR.=$out);

 Show Table('nav3 table1 width100',"<tr><td width='50%' valign=top>$OUTL</td><td valign=top>$OUTR</td></tr>");
 &Exit; # платежи админа не выводим, только список админов
}

# --------------------------------------
#	Вывод списка работников
# --------------------------------------
sub zarplata
{
 $Fnodeny='zarplata';
 $F{uid}=0; # далее покажем последние зарплаты на всех

 $out='';
 $sql="SELECT * FROM j_workers ORDER BY state,name_worker";
 ($sql,$page_buttons,undef,$db) = Show_navigate_list($sql, $F{start}, 25, $Url->new(act=>$Fact));
 while( my %p = $db->line )
 {
    $name_worker = $p{name_worker};
    $id = $p{worker};
    $out .= &RRow($p{state}==3? 'rowoff':'*','lllcc',
       &ahref("$scrpt&a=oper&act=workers&op=edit&id=$id",$name_worker),
       '',
       $p{post},
       &CenterA("$scrpt&uid=-$id",'история'),
    );
 }

 if( !$out )
 {
    Show MessageBox( 'В доступных вам отделах нет ни одного работника.' );
    return;
 }

 Doc->template('top_block')->{title} = 'Работники';

 Show Table('tbg1 width100',
   ($page_buttons && &RRow('tablebg','5',$page_buttons)).
   &RRow('head','ccccc','Имя','Отдел','Должность','История','Выдать<br>зарплату').
   $out
 ).$br2;
}

# -----------------------------------------
#	Список категорий платежей
# -----------------------------------------
sub list_categories
{
 @cols=();
 $url="$scrpt&nodeny=category&year=$ses::year_now&mon=$ses::mon_now&category=";
 $cols[int($_/100)].=&ahref($url.$_,$ct{$_}) foreach (sort {$ct{$a} cmp $ct{$b}} (keys %ct));

 Show Table('tbg1 nav2',
  &RRow('head','ccccccccc',
    'Безналичное пополнение счета клиента',
    'Безналичное снятие со счета клиента',
    'Наличное пополнение счета клиента',
    'Наличное снятие со счета клиента',
    'Вложения в сеть',
    'Затраты сети',
    'Выплаты работникам',
    'Иные',
    'Без категории'
  ).
  &RRow('row2','^^^^^^^^^',
    $cols[0],
    $cols[1],
    $cols[6],
    $cols[7],
    $cols[2],
    $cols[3],
    $cols[9],
    $cols[4].$cols[5],
    &ahref($url.'0','БЕЗ категории')
  )
 );     
 &Exit;
}

1;
