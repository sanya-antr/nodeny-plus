#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
$d={
	'name'		=> 'предустановленного подключения',
	'tbl'		=> 'newuser_opt',
	'field_id'	=> 'id',
	'priv_show'	=> $Adm->{pr}{main_tunes},
	'priv_edit'	=> $Adm->{pr}{edt_main_tunes},
};

sub o_menu
{
 ToTop 'Предустановленные подключения';
 return
	&ahref($scrpt,'Список по id').
	&ahref("$scrpt&order=1",'Список по имени').
	&ahref("$scrpt&order=2",'Список по состоянию').
	&ahref("$scrpt&order=3",'Список по снятию').$br.
	($Adm->{pr}{edt_main_tunes} && &ahref("$scrpt&op=new",'Создать новое')).$br.
	&ahref("$scrpt0&a=operations&act=help&theme=newuser_opt",'Справка');
}

sub o_list
{
 $out='';
 $order_by=('id','opt_name','opt_enabled','pay_sum')[int $F{order}] || 'id';
 $sth=&sql($dbh,"SELECT * FROM newuser_opt ORDER BY $order_by");
 while ($p=$sth->fetchrow_hashref)
   {
    ($id,$opt_time,$pay_sum,$opt_enabled,$opt_action)=&Get_fields('id','opt_time','pay_sum','opt_enabled','opt_action');
    ($opt_name,$opt_comment)=&Get_filtr_fields('opt_name','opt_comment');
    $out.=&RRow($opt_enabled? '*' : 'rowoff','clrcclcc',
       $id,
       $opt_name,
       $pay_sum,
       !!$opt_enabled && ($opt_enabled==1? 'основной записи' : 'алиаса'),
       !!$opt_action && 'есть',
       $opt_comment,
       &ahref("$scrpt&op=edit&id=$id'",$d->{button}),
       $Adm->{pr}{edt_main_tunes} && &ahref("$scrpt&op=del&id=$id'",'X')
    );
   }

 !$out && &Error('В базе данных нет ни одного предустановленного подключения.'.$br2.
    &ahref("$scrpt0&a=operations&act=help&theme=newuser_opt",'Справка по предустановленным подключениям').$br2.
    &ahref("$scrpt&op=new",'Создать предустановленное подключение'),$tend);

 $OUT.=&Table('tbg1 nav3 width100',
   &RRow('head','8',&bold_br('Список предустановленных подключений')).
   &RRow('tablebg','ccccccC','Id','Название',"Сумма снятия, $gr",'Только для','Запланированное действие','Комментарий','Операции').$out);
}

sub o_getdata
{
 $p=&sql_select_line($dbh,"SELECT * FROM newuser_opt WHERE id=$Fid LIMIT 1");
 !$p && &Error($d->{when_deleted} || "Ошибка получения данных предустановленного подключения № $Fid",$tend);

 ($opt_name,$opt_time,$pay_sum,$opt_enabled,$opt_action,$opt_comment,$pay_comment,$pay_reason)=&Get_fields qw(
   opt_name  opt_time  pay_sum  opt_enabled  opt_action  opt_comment  pay_comment  pay_reason );
 $opt_name=&Filtr($opt_name);
 $d->{name}=&Printf('предустановленного подключения [commas]',$opt_name);

 @f = (
   ["plans2 WHERE name<>'' AND","$scrpt0&a=tarif&act=show&id="],
   ['plans3 WHERE',"$scrpt&act=plans3&op=edit&id="],
 );
 $h='';
 foreach $f (@f)
   {
    $sth=&sql($dbh,"SELECT id,name FROM $f->[0] newuser_opt=$Fid");
    $h.=$br.&ahref("$f->[1]$_->{id}",$_->{name}) while ($_=$sth->fetchrow_hashref);
    !$h && next;
   }
 $d->{no_delete}='оно используется в тарифных планах:'.$br.$h if $h;
}

sub o_new
{
 $opt_name=$opt_comment=$pay_comment=$pay_reason='';
 $opt_time=$pay_sum=$opt_action=0;
 $opt_enabled=1;
}

sub o_show
{
 ToTop $d->{name_action};
 $opt_status.='<select name=opt_enabled>'.
   '<option value=0'.($opt_enabled==0 && ' selected').'>Отключено</option>'.
   '<option value=1'.($opt_enabled==1 && ' selected').'>Для основной записи</option>'.
   '<option value=2'.($opt_enabled==2 && ' selected').'>Для алиасной записи</option>'.
 '</select>';

 $OUT.=&form(%{$d->{form_header}},&Table('tbg1',
    &RRow('*','lll','Название',v::input_t('opt_name',$opt_name,50,127),'').
    &RRow('*','lll','Сумма снятия',v::input_t('pay_sum',$pay_sum,50,127),'Сумма, на которую будет изменен баланс клиента и проведен соответствующий платеж сразу же после создания учетной записи. Число может быть как положительным (бонус) так и отрицательным. Нулевое значение отключает создание платежа.').
    &RRow('*','lll','Статус',$opt_status,'Отключено - администраторы не смогут использовать это подключение.<br><br>'.
     					'Для основной записи - подключение можно будет применить только при создании основной записи, для алиасной оно не будет выводиться.<br><br>'.
     					'Для алиасной записи - подключение можно будет применить только при создании алиасной записи, для основной оно не будет выводиться. Обратите внимание - можно указывать стоимость подключения.').
    &RRow('*','lll','Запланированное действие',v::input_t('opt_action',$opt_action,50,127),'Если указать ненулевое значение, то сразу после создания учетной записи, в таблицу платежей будет записано специальное '.&commas('запланированное событие'),', которое автоматически будет выполнено через заданный промежуток времени. В данный момент автор предусмотрел только одно событие с кодом 1 - удваивание всех положительных платежей через сутки. Применяеся для акций. Жду пожеланий').
    &RRow('*','lll','Время запланированного действия',v::input_t('opt_time',$opt_time,50,127),'Количество секунд после создания учетной записи, через которое будет выполнено запланированное событие.').
    &RRow('*','lll','Комментарий к платежу',v::input_ta('pay_comment',$pay_comment,38,6),'Комментарий, который будет установлен в платеже снятии за подключение. Например, укажите '.&commas('Подключение по акции')).
    &RRow('*','lll','Дополнительные данные',v::input_ta('pay_reason',$pay_reason,38,6),'Допустим, при создании подключения в обязательном порядке требуется зарегистрировать какие-либо данные, например, в акционном подключении '.&commas('подключись по флаеру').' необходимо указать номер флаера дабы избежать махинаций со стороны персонала. '.
					'В таком случае укажите в этом поле текст, который будет вставлен в платежное поле, видимое только для администраторов. В тексте укажите $1 - тогда в этом месте будут отображены те данные, которые ввел администратор во время создания предустановленного подключения.').
    &RRow('*','lll','Комментарий',v::input_ta('opt_comment',$opt_comment,38,6),'Комментарий к данному подключению. Будет выводиться исключительно администратору чтобы он в списке подключений мог выбрать то, которое нужно.').
    ($Adm->{pr}{edt_main_tunes} && &RRow('head','3',&submit_a('Сохранить')))
 ));
}

sub o_save
{
 $Fopt_name=&Printf('[filtr|trim]',$F{opt_name}) || 'Новое подключение';

 $Fpay_sum=$F{pay_sum}+0;
 abs($Fpay_sum)>1_000_000 && &Error("Слишком большая сумма платежа.$go_back",$tend);
 $Fopt_enabled=int $F{opt_enabled};
 $Fopt_enabled=1 if $opt_enabled<0 || $opt_enabled>2;
 $Fopt_action=int $F{opt_action};
 $Fopt_time=int $F{opt_time};

 $Fpay_comment=$F{pay_comment};
 $Fpay_reason=$F{pay_reason};
 $Fopt_comment=$F{opt_comment};

 $d->{sql}="opt_name='$Fopt_name',".
	"pay_comment='".&Filtr_mysql($Fpay_comment)."',".
	"pay_reason='".&Filtr_mysql($Fpay_reason)."',".
	"opt_comment='".&Filtr_mysql($Fopt_comment)."',".
	"pay_sum=$Fpay_sum,opt_enabled=$Fopt_enabled,opt_action=$Fopt_action,opt_time=$Fopt_time";

 $rec_state=('отключено','для основной','для алиасной')[$Fopt_enabled];
 if ($Fid)
   {
    $d->{new_data}=$Fopt_name ne $opt_name && 'Новое название: '.&commas($Fopt_name);
    $d->{new_data}.=($d->{new_data} && '. ')."Изменена сумма снятия с $pay_sum на $Fpay_sum" if $Fpay_sum!=$pay_sum;
    $d->{new_data}.=($d->{new_data} && '. ')."Состояние: $rec_state" if $Fopt_enabled!=$opt_enabled;
    $d->{new_data}.=($d->{new_data} && '. ')."Запланированное действие установлено в $Fopt_action" if $Fopt_action!=$opt_action;
   }
    else
   {
    $d->{new_data}='Название: '.&commas($Fopt_name).", сумма снятия $Fpay_sum, состояние: $rec_state, запланированное действие: $Fopt_action";
   }
}

1;
