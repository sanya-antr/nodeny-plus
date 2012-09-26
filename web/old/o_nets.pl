#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$d={
	'name'		=> 'направления',
	'tbl'		=> 'nets',
	'field_id'	=> 'id',
	'priv_show'	=> $Adm->{pr}{Admin},
	'priv_edit'	=> $Adm->{pr}{edt_main_tunes},
};

sub CenterA
{
 return Center( div('nav',ahref(@_)) );
}

sub o_menu
{
 my $out=join '',map{ &ahref("$scrpt&preset=$_"," Пресет $_: ".$Presets{$_}) } (sort {$a <=> $b} keys %Presets);
 my $Fpreset=int $F{preset};
 return	&ahref("$scrpt&op=new&preset=$Fpreset",'Новое направление').
	&ahref("$scrpt&op=new&p=1&preset=$Fpreset",'Новое название').$br. 
	&ahref("$scrpt&preset=-1",'Все пресеты').
	&ahref($scrpt,' Пресет: нулевой').
	$out.$br.
	&ahref("$scrpt&a=operations&act=help&theme=nets_help",'Справка');
}

sub o_list
{
 $colspan=7;
 $Fpreset=int $F{preset};
 $where=$Fpreset>=0 && "WHERE preset=$Fpreset";
 $title_row=&RRow('tablebg','ccccccc','Приоритет','Сеть','Порт','Направление','Комментарий','Изменить','Удалить');
 $old_preset=-1;
 $title_row_now='';
 $out='';
 $sth=&sql($dbh,"SELECT * FROM nets $where ORDER BY preset,priority,class");
 while ($p=$sth->fetchrow_hashref)
 {
    $preset=$p->{preset};
    $preset_name=$preset? $Presets{$preset} || '<span class=error>Неизвестный</span>' : 'Нулевой';
    if( $old_preset!=$preset )
    {
       $out.=&RRow('head',$colspan,$br."Пресет №<b>$preset<b>:&nbsp;&nbsp;&nbsp;<b>$preset_name</b>".$br2);
       $title_row_now=$title_row;
       %traf_name=();
    }
    $old_preset=$preset;
    ($id,$class,$port,$priority)=&Get_fields('id','class','port','priority');
    $comment=v::filtr($p->{comment});
    $comment=~s|\n|<br>|g;
    if( $Adm->{pr}{edt_main_tunes} )
    {
       $button_edit=&CenterA("$scrpt&op=edit&id=$id",'Ред');
       $button_del=&CenterA("$scrpt&op=del&id=$id",'Х');
    }else
    {
       $button_edit=$button_del='';
    } 
    if( $priority )
    {
       $name_traf=$class? $traf_name{$class}||$class : '<span class=disabled>неучитываемый</span>';
       $out.=$title_row_now.&RRow('*','cllllll',$priority,v::filtr($p->{net}),$port,$name_traf,$comment,$button_edit,$button_del);
       $title_row_now='';
    }
     else 
    {
       $traf_name{$class}=$comment;
       $out.=&RRow('*','cr3ll',"Направление <b>$class</b>","<span class=data1>$comment</span> трафик",($port? 'таблица ipfw: '.v::bold($port):''),$button_edit,$button_del);
    } 
 }

 $out or &Error($Fpreset>=0? "В базе данных нет ни одной записи в $Fpreset-м пресете направлений." : 'В базе данных нет ни одной записи о направлениях',$tend);

 Show Table('tbg1 width100 nav',$out);
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM nets WHERE id=$Fid LIMIT 1");
 $p or &Error($d->{when_deleted} || "Ошибка получения данных направления id=$Fid.",$tend);
 $preset=$p->{preset};
 $priority=$p->{priority};
 $net=&Filtr($p->{net});
 $port=$p->{port};
 $class=$p->{class};
 $comment=&Filtr($p->{comment});
 $d->{old_data}=$priority? "Пресет: $preset, приоритет: $priority, сеть: $net, порт: $port, класс: $class" :
    "Пресет: $preset, класс: $class, таблица ipfw: $port, название направления: ".&commas($comment);
}

sub o_new
{
 $preset=int $F{preset};
 $preset=0 if $preset<0;
 $class=0;
 $net=$port=$comment='';
 $priority=$F{p}? 0:100;
 $d->{name_action}=$priority? 'Создание направления' : 'Создание названия направления';
}

sub o_show
{
 $ses::role eq 'admin' or Error($Mess_UntrustAdmin,$tend);
 $show_presets='<select name=preset size=1>';
 $show_presets.='<option value=0>Нулевой пресет</option>';
 $show_presets.="<option value=$_>$Presets{$_}</option>" foreach (sort {$a <=> $b} keys %Presets);
 $show_presets.="<option value=$preset selected>№ $preset</option>" unless $show_presets=~s/<option value=$preset>/<option value=$preset selected>/;
 $show_presets.='</select>';

 Show form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','C',v::bold($d->{name_action})).
     &RRow('*','ll','Номер пресета',$show_presets).
     &RRow('*','ll','Номер направления',v::input_t('class',$class,5,30)).
     ($priority?
       &RRow('*','ll','Приоритет',v::input_t('priority',$priority,5,30)).
       &RRow('*','ll','Сеть',v::input_t('net',$net,40,255)).
       &RRow('*','ll','Порт',v::input_t('port',$port,5,10)).
       &RRow('*','ll','Комментарий',v::input_t('comment',$comment,40,255)) :

       &RRow('*','ll','Название направления',v::input_t('comment',$comment,40,128).' трафик').
       &RRow('*','ll','Номер таблицы фаервола',v::input_t('port',$port,4,30)).
       &RRow('*',' l','','Комментарий: в указанную таблицу ipfw на сателлите будут записаны все сети данного направления и пресета. '.
            'В ipfw таблиц всего 128. С 0 по 29 зарезервированы NoDeny. Вы можете использовать 30..126 и только четные значения!<br>0 - отключить запись в таблицы')
     ).
     ($Adm->{pr}{edt_main_tunes} && &RRow('head','C', v::submit('Сохранить') ))
   )
 );
}

sub o_save
{
 $ses::role eq 'admin' or Error($Mess_UntrustAdmin,$tend);
 $Fnet=$F{net};
 $Fnet=~s|\s+||g;
 $Fpriority=int $F{priority};
 $Fpriority && $Fnet!~/^(file:.+|\d+\.\d+\.\d+\.\d+(\/\d+)?)$/ && &Error('Описание направления не сохранено т.к '.
   'сеть задана неверно! Сеть должна быть задана в виде <b>xx.xx.xx.xx/yy</b>, <b>xx.xx.xx.xx</b> либо <b>file:имя файла</b>',$tend);

 $Fcomment=&Filtr($F{comment});
 $Fpreset=int $F{preset};
 $Fclass=int $F{class};
 $Fport=int $F{port};
 $d->{sql}="preset=$Fpreset,priority=$Fpriority,net='$Fnet',port=$Fport,class=$Fclass,comment='$Fcomment'";
 $d->{new_data}=$Fpriority? "Пресет: $Fpreset, приоритет: $Fpriority, сеть: $Fnet, порт: $Fport, класс: $Fclass" :
    "Пресет: $Fpreset, класс: $Fclass, таблица ipfw: $Fport, название направления: ".&commas($Fcomment);

 $scrpt.="&preset=$Fpreset"; # для кнопки `продолжить`
}

1;
