#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

$d={
	'name'		=> 'дополнительного тарифа',
	'tbl'		=> 'plans3',
	'field_id'	=> 'id',
	'priv_show'	=> $Adm->{pr}{tarifs},
	'priv_edit'	=> $Adm->{pr}{edt_tarifs},
};

sub o_menu
{
 return	&bold_br('Дополнительные тарифы').
        &ahref($scrpt,'Список').
	($Adm->{pr}{edt_tarifs} && &ahref("$scrpt&op=new",'Создать новый')).
	$br.&ahref("$scrpt0&a=operations&act=help&theme=plans3",'Справка');
}

sub o_list
{
 $out='';
 $sth=&sql($dbh,"SELECT p.*,COUNT(u.id) AS n FROM plans3 p LEFT JOIN users u ON p.id=u.paket3 GROUP BY p.id ORDER BY p.name");
 while ($p=$sth->fetchrow_hashref)
   {
    ($id,$users,$name,$price)=&Get_fields('id','n','name','price');
    $out.=&RRow('*','cllccc',
       $id,
       '&nbsp;&nbsp;'.&Filtr($name),
       '&nbsp;&nbsp;'.$price,
       $users,
       &ahref("$scrpt&op=edit&id=$id",$d->{button}),
       (!$users && $Adm->{pr}{edt_tarifs} && &ahref("$scrpt&op=del&id=$id",'X'))
    );
   }

 $out or &Error('В базе данных нет ни одного дополнительного тарифа.'.$br2.&CenterA("$scrpt&op=new",'Создать тариф &rarr;'),$tend);

 $OUT.=&Table('tbg3 nav3 width100',
   &RRow('head','6',&bold_br('Список отделов')).
   &RRow('tablebg','cccccc','№ Тарифа','Название','Абонплата','Количество клиентов','Изменить','Удалить').$out);
}

sub o_new
{
 $name=$usr_grp=$usr_grp_ask=$descr='';
 $price=$price_change=$newuser_opt=0;
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM plans3 WHERE id=$Fid");
 $p or &Error($d->{when_deleted} || "Ошибка получения данных дополнительного тарифа номер $Fid",$tend);
 $name=&Filtr($p->{name});
 $descr=$p->{descr};
 ($price,$price_change,$usr_grp,$usr_grp_ask,$newuser_opt)=&Get_fields qw(
   price  price_change  usr_grp  usr_grp_ask  newuser_opt );
 $d->{no_delete}='в таблице платежей существуют записи `история смен дополнительных тарифов`, в котором указан данный тариф. '.
    'Другими словами, ранее данный тариф использовался как минимум одним клиентом. Вместо удаления тарифа уберите в нем галки '.
    'доступа клиентских групп.' if  &sql_select_line($dbh,"SELECT * FROM pays WHERE category=433 AND type=50 AND reason LIKE '%:$Fid\\n%' LIMIT 1");
 $d->{no_delete}='Существуют клиенты с данным пакетом тарификации.' if 
    &sql_select_line($dbh,"SELECT * FROM users WHERE mid=0 AND paket3=$Fid LIMIT 1");
 $d->{name}='дополнительного тарифа '.&commas($name);
}

sub o_show
{
 $usr_grp_list=$usr_grp_ask_list='';
 foreach $i( sort{ $Ugrp->{$a}{name} cmp $Ugrp->{$b}{name} } grep $Adm->{grp_lvl}{$_}, keys %$Ugrp )
 {
    $h= $Ugrp->{$i}{name}.$br;
    $usr_grp_list.="<input type=checkbox value=1 name=grp_$i".($usr_grp=~/,$i,/ && ' checked')."> $h";
    $usr_grp_ask_list.="<input type=checkbox value=1 name=grpa_$i".($usr_grp_ask=~/,$i,/ && ' checked')."> $h";
 }

 $newuser_opt_list='';
 $sth=&sql($dbh,"SELECT * FROM newuser_opt WHERE opt_enabled=1 ORDER BY opt_name");
 while ($p=$sth->fetchrow_hashref)
   {
    $id=$p->{id};
    $newuser_opt_list.="<option value=$id".($id==$newuser_opt && ' selected').'>'.&Filtr($p->{opt_name}).'</option>';
   }
 $newuser_opt_list="<select name=newuser_opt><option value=0>&nbsp;</option>$newuser_opt_list</select>" if $newuser_opt_list;

 $OUT.=&form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','C',&bold_br($d->{name_action})).
     &RRow('*','ll','Название тарифа',v::input_t('name',$name,40,127)).
     &RRow('*','ll',"Цена, $gr",v::input_t('price',$price,15,30)).
     &RRow('*','ll',"Цена смены тарифа, $gr",v::input_t('price_change',$price_change,15,30)).
     ($newuser_opt_list && &RRow('*','ll','Предустановленное подключение',"При создании клиентской учетной записи, если будет выбрат данный пакет, то произойдет автоматическое снятие финансов по статье:$br2$newuser_opt_list")).
     &RRow('*','ll','Можно устанавливать клиентам в группах',$usr_grp_list).
     &RRow('*','ll','Могут заказывать клиенты в группах',$usr_grp_ask_list).
     &RRow('*','ll','Описание тарифа (видно клиентам)',v::input_ta('descr',$descr,30,5)).
     ($Adm->{pr}{edt_tarifs} && &RRow('head','C',&submit_a('Сохранить')))
   )
 );
}

sub o_save
{
 $Fname=&Printf('[filtrfull|trim]',$F{name});
 $Fname eq '' && &Error("Дайте название тарифу.$go_back",$tend);
 $Fname='0.' if !$Fname;
 $Fprice=$F{price};
 $Fprice=~s|[,юб/\?]|.|;
 $Fprice+=0;
 $Fprice_change=$F{price_change};
 $Fprice_change=~s|[,юб/\?]|.|;
 $Fprice_change+=0;
 $Fdescr=&Filtr_mysql($F{descr});
 $Fnewuser_opt=int $F{newuser_opt};
 $Fnewuser_opt=0 if $Fnewuser_opt<0;

 $Fusr_grp=join ',', sort {$a <=> $b} grep $F{"grp_$_"}, keys %$Ugrp;
 $Fusr_grp_ask=join ',', sort {$a <=> $b} grep $F{"grpa_$_"}, keys %$Ugrp;
 $Fusr_grp=~s|(.+)|,$1,|;
 $Fusr_grp_ask=~s|(.+)|,$1,|;

 $d->{sql}="name='$Fname',price=$Fprice,price_change=$Fprice_change,usr_grp='$Fusr_grp',".
    "newuser_opt=$Fnewuser_opt,usr_grp_ask='$Fusr_grp_ask',descr='$Fdescr'";

 $_=&commas($Fname);
 if ($Fid)
   {# изменение, а не создание тарифа
    $new_data=$Fname ne $name && "Новое название тарифа $_";
    $new_data.=($new_data && '. ')."Цена  $Fprice $gr" if $Fprice != $price;
    $new_data.=($new_data && '. ')."Стоимость переключения $Fprice_change $gr" if $Fprice_change != $price_change;
    $new_data.=($new_data && '. ').($Fnewuser_opt ? "Предустановленное подключение № $Fnewuser_opt" : 
      'Убрана ссылка на предустановленное подключение') if $Fnewuser_opt != $newuser_opt;
    $new_data.=($new_data && '. ').'Изменен список групп клиентов, которым можно назначать тариф' if $Fusr_grp ne $usr_grp;
    $new_data.=($new_data && '. ').'Изменен список групп клиентов, которые могут заказывать тариф' if $Fusr_grp_ask ne $usr_grp_ask;
   }else
   {
    $new_data="Название $_, цена $Fprice $gr";
    $new_data.=", стоимость переключения $Fprice_change $gr " if $Fprice_change;
    $new_data.=", предустановленное подключение № $Fnewuser_opt" if $Fnewuser_opt;
   }
 $d->{new_data}=$new_data;
}

1;
