#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$d={
	'name'		=> 'группы контактов',
	'tbl'		=> 'c_grps',
	'field_id'	=> 'grp',
	'priv_show'	=> $Adm->{pr}{98},
	'priv_edit'	=> $Adm->{pr}{99},
};

sub o_menu
{
 return	&bold_br('Группы контактов').
	&ahref($scrpt,'Список групп').
	($Adm->{pr}{99} && &ahref("$scrpt&op=new",'Новая группа')).$br.
	&ahref("$scrpt&act=contacts",'Контакты').
	&ahref("$scrpt0&a=operations&act=help&theme=c_grp",'Справка');
}

sub o_list
{
 $out='';
 $where=!$Adm->{pr}{104} && " WHERE g.office IN (0,$Adm->{office})";
 $sth=&sql($dbh,"SELECT g.*,COUNT(c.grp) AS n FROM c_grps g LEFT JOIN c_contacts c ON g.grp=c.grp $where GROUP BY g.grp ORDER BY g.office,g.name_grp");
 while ($p=$sth->fetchrow_hashref)
   {
    ($grp,$office,$name_grp,$n)=&Get_filtr_fields('grp','office','name_grp','n');
    $h=$Adm->{pr}{99} && ($Adm->{pr}{105} || $office==$Adm->{office}); # 105 - ред. контакты чужих отделов
    $out.=&RRow('*','llccc',
      $name_grp,
      $cfg::Offices{$office} || '<span class=disabled>доступно всем отделам</span>',
      $n,
      &ahref("$scrpt&op=edit&id=$grp'",$h? 'Ред':'Смотреть'),
      $h && $n<1? &ahref("$scrpt&op=del&id=$grp'",'X') : ''
    );
   }

 $out or &Error(($Adm->{pr}{104}? 'Не создано ни одной группы контактов.' :
                  'Не создано ни одной группы контактов вашем отделе.').$br2.
    ($Adm->{pr}{99} && &ahref("$scrpt&op=new",'Создать группу')),$tend);

 $OUT.=&Table('tbg3 nav3 width100',
   &RRow('head','5',&bold_br('Группы контактов')).
   &RRow('tablebg','cccC','Группа контактов','Отдел','Контактов','Операции').$out);
}

sub o_show
{
 if ($Adm->{pr}{105})
   {# есть права на изменение контактов чужих отделов
    $offices=&Get_Office_List($office);
   }else
   {# в любом случае в скрытом поле сохраним номер отдела т.к в момент записи права на изменения в чужих отделах могут быть даны
    $offices=v::input_h('office',$office).($cfg::Offices{$office} || 'ВСЕМ ОТДЕЛАМ');
   } 

 $OUT.=&form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','C',&bold_br($d->{name_action})).
     &RRow('*','ll','Название группы',v::input_t('name_grp',$name_grp,50,127)).
     &RRow('*','ll','Будет доступна только отделу',$offices).
     &RRow('head','C',$Adm->{pr}{99} && ($Adm->{pr}{105} || $office==$Adm->{office})? &submit_a('Сохранить') : "$go_back<br><br>")
   )
 );
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT g.*,COUNT(c.grp) AS n FROM c_grps g LEFT JOIN c_contacts c ON g.grp=c.grp WHERE g.grp=$Fid GROUP BY g.grp");
 unless ($p)
   {
    $_=&sql_select_line($dbh,"SELECT time FROM changes WHERE tbl='c_grps' AND act=2 AND fid=$Fid");
    &Error(&the_short_time($_->{time},$t)." Группа контактов № $Fid была удалена.",$tend) if $_;
    &Error("Ошибка получения данных группы контактов № $Fid",$tend);
   }
 ($name_grp,$office,$n)=&Get_filtr_fields('name_grp','office','n');
 &Error("У вас нет доступа к контактам других отделов.",$tend) if !$Adm->{pr}{104} && $office && $office!=$Adm->{office};
 $d->{priv_edit}=$office!=$Adm->{office}? $Adm->{pr}{105} : $Adm->{pr}{99}; # если отдел другой, то установим требование права редактирования контактов чужих отделов
 $d->{no_delete}='группа содержит контакты. Удалите их или перенесите в другую группу.' if $n>0; # установим флаг, что удалять нельзя
 $_='группы контактов '.&commas($name_grp);
 $_.=' отдела '.commas($cfg::Offices{$office}) if $cfg::Offices{$office};
 $d->{name}=$_;
}

sub o_new
{
 $name_grp='';
 $office=$Adm->{office};
}

sub o_save
{
 $Fname_grp=&trim(&Filtr($F{name_grp}));
 $Fname_grp eq '' && &Error("Вы не указали название группы контактов. Изменения не внесены.$go_back",$tend);
 $Foffice=int $F{office};
 !$Adm->{pr}{105} && $Foffice!=$Adm->{office} && &Error("Вам не разрешено редактировать контакты других отделов.",$tend);
 $d->{sql}="name_grp='".&Filtr_mysql($Fname_grp)."',office=$Foffice";
 $d->{new_data}=$Fname_grp ne $name_grp && 'Новое название группы контактов: '.&commas($Fname_grp);
}

1;
