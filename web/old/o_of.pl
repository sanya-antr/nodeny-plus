#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt

$d={
	'name'		=> 'отдела',
	'tbl'		=> 'offices',
	'field_id'	=> 'of_id',
	'priv_show'	=> $Adm->{pr}{main_tunes},
	'priv_edit'	=> $Adm->{pr}{edt_main_tunes},
};

sub o_menu
{
 return	&ahref($scrpt,'Список отделов').
	($Adm->{pr}{edt_main_tunes} && &ahref("$scrpt&op=new",'Новый отдел'));
}

sub o_list
{
 $out='';
 $sth=&sql($dbh,"SELECT o.*,COUNT(a.office) AS n FROM offices o LEFT JOIN admin a ON o.of_id=a.office GROUP BY o.of_id ORDER BY of_name");
 while ($p=$sth->fetchrow_hashref)
   {
    ($id,$admins,$of_name)=&Get_fields('of_id','n','of_name');
    $out.=&RRow('*','clccc',
       $id,
       '&nbsp;&nbsp;'.&Filtr($of_name),
       $admins,
       &ahref("$scrpt&op=edit&id=$id",$d->{button}),
       (!$admins && $Adm->{pr}{edt_main_tunes} && &ahref("$scrpt&op=del&id=$id",'X'))
    );
   }

 $out or &Error('В базе данных нет ни одного отдела.'.$br2.&ahref("$scrpt&op=new",'Создать отдел'),$tend);

 Show Table('tbg3 nav3 width100',
   &RRow('head','5',&bold_br('Список отделов')).
   &RRow('tablebg','ccccc','Id отдела','Название','Количество администраторов','Изменить','Удалить').$out);
}

sub o_new
{
 $of_name='';
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM offices WHERE of_id=$Fid");
 $p or &Error($d->{when_deleted} || "Ошибка получения данных отдела с id=$Fid",$tend);
 $of_name=&Filtr($p->{of_name});
 $d->{no_delete}='в отделе числятся администраторы. Переведите их в другой отдел.' if &sql_select_line($dbh,"SELECT * FROM admin WHERE office=$Fid LIMIT 1");
 $d->{no_delete}='есть '.&ahref("$scrpt&act=c_grp",'группы контактов').', которые закреплены за данным отделом. Переведите их в другой отдел.' if &sql_select_line($dbh,"SELECT * FROM c_grps WHERE office=$Fid LIMIT 1");
 $d->{name}='отдела '.&commas($of_name);
}

sub o_show
{
 Show form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','C',&bold_br($d->{name_action})).
     &RRow('*','ll','Название отдела',v::input_t(name=>'of_name',value=>$of_name)).
     ($Adm->{pr}{edt_main_tunes} && &RRow('head','C',&submit_a('Сохранить')))
   )
 );
}

sub o_save
{
 $Fof_name=&trim(&Filtr($F{of_name}));
 ($Fof_name eq '') && &Error("Дайте название отделу",$tend);
 $d->{sql}="of_name='$Fof_name'";
 $d->{new_data}=($Fof_name ne $of_name) && "Новое имя отдела: $Fof_name";
}

1;
