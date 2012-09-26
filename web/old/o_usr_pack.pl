#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$d={
	'name'		=> 'объединения групп клиентов',
	'tbl'		=> 'user_grppack',
	'field_id'	=> 'id',
	'priv_show'	=> $Adm->{pr}{main_tunes},
	'priv_edit'	=> $Adm->{pr}{edt_main_tunes},
};

sub o_menu
{
 return	&ahref($scrpt,'Список объединений').
	($Adm->{pr}{edt_main_tunes} && &ahref("$scrpt&op=new",'Новое объединение')).
	&ahref("$scrpt0&a=operations&act=help&theme=grppack",'Справка по объединению групп');
}
sub o_list
{
 $out='';
 $sth=&sql($dbh,"SELECT * FROM user_grppack");
 while ($p=$sth->fetchrow_hashref)
   {
    ($id,$pack_name,$pack_grps)=&Get_filtr_fields('id','pack_name','pack_grps');
    $pack_grps=~s|^,||;
    $pack_grps=~s|,$||;
    $out.=&RRow('*','llcc',
      $pack_name,
      $pack_grps || '<span class=disabled>ни одной группы в объединении</span>',
      &ahref("$scrpt&op=edit&id=$id",$d->{button}),
      $Adm->{pr}{edt_main_tunes} && &ahref("$scrpt&op=del&id=$id",'X')
    );
   }
 &Error('В базе данных нет ни одного объединения групп клиентов.<br><br>'.&ahref("$scrpt&op=new",'Создать'),$tend) unless $out;
 
 $OUT.=&Table('tbg1 nav3 width100',&RRow('head','4',&bold_br('Объединения групп клиентов')).$out);
}

sub o_new
{
 $pack_name=$pack_grps='';
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM user_grppack WHERE id=$Fid LIMIT 1");
 &Error("Ошибка получения данных объединения групп с id=$Fid",$tend) unless $p;
 ($pack_name,$pack_grps)=&Get_filtr_fields('pack_name','pack_grps');
 $pack_grps=~s|^,||;
 $pack_grps=~s|,$||;
 $d->{old_data}="имя объединения: $pack_name, входящие в него группы: $pack_grps";
 $pack_grps=",$pack_grps" if $pack_grps!~/^,/;
 $pack_grps.=',' if $pack_grps!~/,$/;
 
}

sub o_show
{
 @grps=();
 $i=0;
 $n=3/((keys %UGrp_name)||1);
 foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
  {
   $grps[int($i)].="<input type=checkbox value=1 name=g$g".($pack_grps=~/,$g,/ && ' checked')."> $UGrp_name{$g}".$br;
   $i+=$n;
  }

 $OUT.=&form(%{$d->{form_header}},
   &Table('tbg1',
     &RRow('head','4',&bold_br($d->{name_action})).
     &RRow('*','l3','Название объединения',v::input_t('pack_name',$pack_name,70,128)).
     &RRow('*','llll','Группы, входящие в объединение',$grps[0],$grps[1],$grps[2]).
     &RRow('*','4',&submit_a('Сохранить'))
   )
 );
}

sub o_save
{
 $grps='';
 foreach (keys %UGrp_name) {$grps.="$_," if $F{"g$_"}};
 $pack_name=&Filtr($F{pack_name});
 &Error("Объединение групп не может быть с пустым названием.$go_back",$tend) if $pack_name eq ''; 
 $d->{sql}="pack_name='$pack_name',pack_grps=',$grps'";
 chop $grps;
 $d->{new_data}='Имя объединения: '.&commas($pack_name).", входящие в него группы: $grps";
}


1;
