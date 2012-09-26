#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$d={
	'name'		=> 'точки топологии',
	'tbl'		=> 'points',
	'field_id'	=> 'id',
	'priv_show'	=> $Adm->{pr}{topology},
	'priv_edit'	=> $Adm->{pr}{edt_topology},
};

sub o_menu
{
 return &bold_br('Точки топологии').
   &ahref($scrpt,'Список').
   &ahref("$scrpt&op=new",'Новая точка').$br.
   &ahref("$scrpt&act=str",'Улицы');
}

sub o_list
{
 %box_switches=();		# список ссылок на свичи для каждой точки топологии
 %box_work_ports=();		# рабочих портов на всех свичах каждой точки
 $sth=&sql($dbh,"SELECT * FROM p_switch");
 while ($p=$sth->fetchrow_hashref)
   {
    $box=$p->{box};
    $sw=$p->{switch};
    $box_switches{$box}.=&ahref("$scrpt&act=editsw&sw=$sw",$sw).$br;
    $box_work_ports{$box}+=$p->{all_ports}-$p->{bad_ports};
    $box_sw_count{$box}++;
   }
 
 #$OUT.="<table class='width100 nav row2'><tr><td>Сотня:</td><td>";
 $out=join '',map {&ahref("$scrpt&act=points&p=$_"," $_ ")} (0..20);

 $url=$scrpt;
 $sql="SELECT * FROM points p LEFT JOIN p_street s ON p.street=s.street WHERE 1 ";
 if (defined $F{box})
 {
     $_=int $F{box};
     $sql.=" AND p.box=$_";
     $url.="&box=$_";
 }elsif (defined $F{boxes})
 {
     $_=int $F{boxes};
     $sql.=' AND p.box>='.($_*100).' AND p.box<'.($_*100+100);
     $url.="&boxes=$_";
 }
 if (defined $F{street})
 {
     $_=int $F{street};
     $sql.=" AND p.street=$_";
     $order_by='ORDER BY house';
     $url.="&street=$_";
 }else
 {
     $order_by='ORDER BY box';
 }
 $out='';
 ($sql,$page_buttons,$rows,$sth)=&Show_navigate_list("$sql $order_by",$start,100,$url);
 $page_buttons&&=&RRow('tablebg',9,$page_buttons);

 while ($p=$sth->fetchrow_hashref)
   {
    ($id,$street,$name_street,$house,$block,$pod,$box,$map,$x,$y)=&Get_fields qw (
      id  street  name_street  house  block  pod  box  map  x  y );
    $block=v::filtr($block);
    $out.=&RRow('*','clcclcccc',
      $box,
      &Filtr($name_street),
      $house.($block ne '' && "/$block"),
      v::filtr($pod),
      $box_switches{$box},
      $box_work_ports{$box},
      $x || $y? $map : 'нет',
      &ahref("$scrpt&op=edit&id=$id",$d->{button}),
      ($Adm->{pr}{edt_topology} && &ahref("$scrpt&op=del&id=$id",'X'))
    );
   }

 $out or &Error('Не существует ни  одной точки топологии.'.$br2.&CenterA("$scrpt&op=new",'Создать &rarr;'),$tend);

 $OUT.=&Table('tbg3 nav3 width100',
   &RRow('head','9',&bold_br('Точки топологии')).
   $page_buttons.
   &RRow('tablebg','ccccccccc','№','Улица','Дом','Подъезд','№ свичей','Рабочих портов','Карта','Операции','Удалить').
   $out.
   $page_buttons
 );
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM points WHERE id=$Fid");
 $p or &Error($d->{when_deleted} || "Ошибка получения данных точки топологии id=$Fid",$tend);
 ($box,$house,$cod_pod,$street,$unknown_ports,$comment,$map,$x,$y)=&Get_fields qw(
   box  house  cod_pod  street  unknown_ports  comment  map  x  y );
 ($block,$pod,$connected,$netprotects,$kl4,$power,$net)=&Get_filtr_fields qw(
   block  pod  connected  netprotects  kl4  power  net );
 $d->{name}="точки подключения № $box";
}

sub o_new
{
 $house=$block=$cod_pod=$connected=$comment=$keys=$power=$net='';
 $pod=1;
 $street=$unknown_ports=$box=0;
}

sub o_show
{
 $streets='<select name=street size=1>';
 $sth=&sql($dbh,"SELECT * FROM p_street ORDER BY name_street");
 while ($p=$sth->fetchrow_hashref)
   {
    $_=$p->{street};
    $streets.="<option value=$_".($_==$street && ' selected').'>'.&Filtr($p->{name_street}).'</option>';
   }
 $streets.='</select>';
 $show_map=!!$box && &div('nav',&ahref("$scrpt0&a=map&i=$map&bx=$box",$x>0 || $y>0? 'Показать на карте' : 'Установить на карту'," target='_blank'"));
 $OUT.=&form(%{$d->{form_header}},
   &Table('tbg3',
     &RRow('head','3',&bold_br($d->{name_action})).
     &RRow('*','lll','Номер точки',v::input_t('box',$box||'',10,10),$show_map).
     &RRow('*','lll','Улица',$streets,'').
     &RRow('*','lll','Дом',v::input_t('house',$house,10,10),'').
     &RRow('*','lll','Блок',v::input_t('block',$block,10,10),'можно не число').
     &RRow('*','lll','Подъезд',v::input_t('pod',$pod,10,10),'можно не число').
     &RRow('*','lll','Код подъезда',v::input_t('cod_pod',$cod_pod,10,16),'').
     &RRow('*','lll','Неучтенных портов',v::input_t('unknown_ports',$unknown_ports,10,10),'кол-во портов, к которым подключены неучтенные потребители').
     &RRow('*','lll','Соединения с',v::input_t('connected',$connected,20,127),'номера точек через запятую, с которыми данная точка имеет соединение. Каждая точка уменьшает кол-во свободных портов в данной точке').
     &RRow('*','lll','Грозозащиты',v::input_t('netprotects',$netprotects,20,127),'номера точек через запятую, с которыми данная точка имеет соединение через грозозащиту').
     &RRow('*','lll','Ключ от точки',v::input_t('kl4',$kl4,20,127),'ключ от ящика и др. параметры точки').
     &RRow('*','lll','Питание',v::input_t('power',$power,20,127),'сокращенно, например: Л - лифтовая, О - освещение, Щ - щиток, П - перегородка последнего этажа').
     &RRow('*','lll','Подсеть',v::input_t('net',$net,20,20),'Начальный ip-адрес подсети, при внесении нового клиента будет предложен свободный ip начиная с этого адреса (сделайте буфер для `неклиентских` ip)').
     &RRow('*','lL','Комментарий',v::input_ta('comment',$comment,40,8)).
     &RRow('head','3',$Adm->{pr}{edt_topology}? &submit_a('Сохранить') : $go_back.$br2)
   )
 );
}

sub o_save
{
 $Fbox=int $F{box};
 $Fhouse=int $F{house};
 $Fblock=&Filtr($F{block});
 $Fpod=&Filtr($F{pod});
 $Fcod_pod=int $F{cod_pod};
 $Fstreet=int $F{street};
 $Funknown_ports=int $F{unknown_ports};
 $Fcomment=&Filtr_mysql($F{comment});
 $Fconnected=&Filtr($F{connected});
 $Fnetprotects=&Filtr($F{netprotects});
 $Fkl4=&Filtr($F{kl4});
 $Fpower=&Filtr($F{power});
 $Fnet=$F{net};
 $Fnet=~s|ю|.|g;
 $Fnet=~s|[^\d\./]||g;
 $Fbox>0 or &Error('У точки не должен быть нулевой или отрицательный номер.'.$go_back,$tend);
 $d->{sql}="street=$Fstreet,house=$Fhouse,block='$Fblock',pod='$Fpod',cod_pod=$Fcod_pod,comment='$Fcomment',unknown_ports=$Funknown_ports,".
    "connected='$Fconnected',netprotects='$Fnetprotects',kl4='$Fkl4',power='$Fpower',net='$Fnet',box=$Fbox";

 if ($Fid)
   {# изменение, а не создание точки топологии
    $new_data=($Fbox!=$box) && "Новый номер: $Fbox";
    $new_data.=($new_data && ', ')."номер улицы: $Fstreet" if $Fstreet != $street;
    $new_data.=($new_data && ', ')."дом: $Fhouse" if $Fhouse != $house;
    $new_data.=($new_data && ', ')."блок: $Fblock" if $Fblock ne $block;
    $new_data.=($new_data && ', ')."подъезд: $Fpod" if $Fpod ne $pod;
    $new_data.=($new_data && ', ')."код подъезда: $Fcod_pod" if $Fcod_pod != $cod_pod;
   }else
   {
    $new_data="Номер: $Fbox, номер улицы: $Fstreet, дом: $Fhouse, блок: $Fblock, подъезд: $Fpod, код подъезда: $Fcod_pod";
   }
 $d->{new_data}=$new_data;
}

1;
