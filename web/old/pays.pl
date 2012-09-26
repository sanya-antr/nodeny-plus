#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

sub Table { return("<table class='$_[0]'>$_[1]</table>") }
sub ahref
{
 return "<a href='$_[0]'".($_[2]? " $_[2]":'').">$_[1]</a>";
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
require "$cfg::dir_web/paystype.pl";

$default_act='payform';

%subs=(
 'show'         => \&pay_show,      # вывод формы просмотра/редактирования
 'edit'         => \&pay_edit,      # непосредстенное изменение/удаление
 'plzedit'      => \&plz_edit,      # создание события с просьюой изменить платеж
 'markanswer'   => \&mark_answer,   # установить категорию сообщения как "ответ дан"
 $default_act   => \&payform_show,  # вывод формы для осуществления платежа
 'pay'          => \&pay_now,       # непосредственное проведение платежа
 'send'         => \&send_money,    # перадача наличности между админами
 'mess2all'     => \&mess_for_all,  # отправка многоадресного сообщения
 'set_block'    => \&set_block,     # создание блокировочной записи, например блок.сообщений клиента
 'update_category' => \&update_category, # групповое обновление категорий платежей
);

$Fmid=int $F{mid};
$Fact= defined($subs{$F{act}})? $F{act} : $default_act;

&{ $subs{$Fact} };
Exit();

sub Get_fields
{
 return map{$p->{$_} }(@_);
}
sub CenterA
{
 return Center( div('nav',ahref(@_)) );
}

sub get_pay_data
{
 #Adm->chk_privil('pays') or Error('У вас нет прав на просмотр платежей.');

 $Fid=int $F{id};
 my %p = Db->line("SELECT p.*,INET_NTOA(p.creator_ip),a.login,a.name,a.privil FROM pays p LEFT JOIN admin a ON a.id=p.creator_id WHERE p.id=$Fid"); 

 if( !%p )
 {
    Error("Ошибка получения данных записи c id=$Fid".$br2."Вероятно эта запись отсутствует в таблице платежей.");
 }

 $p = \%p;
 # поля reason и comment не фильтруем т.к понадобятся переводы строк, отфильтруем позже
 ($mid,$bonus,$type,$orig_reason,$orig_comment,$category,$adm_id,$t_pay)=&Get_fields('mid','bonus','type','reason','comment','category','creator_id','time');

 $cash=sprintf("%.2f",$p->{cash});
 $adm_login=v::filtr($p->{login}||'');		# т.к может быть неопределенным 
 $adm_name=v::filtr($p->{name}||'-');
 $admin_ip=$p->{'INET_NTOA(p.creator_ip)'};
 $pay_time=&the_time($t_pay);
 $display_admin=$adm_id? v::bold($adm_login) : 'СИСТЕМА';
 $display_admin.=" ($admin_ip)" if $admin_ip ne '0.0.0.0';

 $can_edit = Adm->chk_privil('edt_pays') || 1;
 $logm = '';

 if( Adm->id != $adm_id )
 {  # чужая запись

    $privil=$p->{privil}.',';
    if ($can_edit && $privil=~/,13,/)
    {  # привилегия 13 - запретить редактирование своих платежей другими администраторами 
       $logm .= '<li>Текущая запись принадлежит админу, который имеет монопольное право на ее редактирование.';
       $logm .= Adm->chk_privil('SuperAdmin')? ' Вам разрешено т.к. вы суперадмин</li>' : '</li>';
       $can_edit=0 unless Adm->chk_privil('SuperAdmin');
    }
 }

 if( $mid>0 )
 {  # запись связана с клиентом
    my $p = Get_usr_info($mid);
    $filtr_name_url = $p->{full_info};
    $grp = $p->{grp};
    $mId = $mid;
    if( $mId )
    {
        Adm->chk_usr_grp($grp) or Error('Вам не разрешен доступ к запрошенной записи.'); # без подробностей т.к это на 99% жулики
    }
     elsif( Adm->chk_privil('SuperAdmin') )
    {
       $filtr_name_url=v::bold("Отсутствующий в базе клиент (id=$mid)");
    }
     else
    {
        Error("Данная запись указывает на отсутствующего в базе клиента. К ней имеет доступ только суперадминистратор.");
    }
 }
  elsif( $mid )
 {  # запись связана с работником
    $wid=-$mid;
    my %p = Db->line("SELECT * FROM j_workers WHERE worker=$wid");
    if( %p )
    {
       $worker_name=$p{name_worker};
       $filtr_name_url='работник ';
    }
     else
    {
       $worker_name='работник отсутствует в БД';
       $filtr_name_url='';
    }
    $filtr_name_url.= $Url->a($worker_name, a=>'oper', act=>'workers', op=>'edit', id=>$wid);
 }
  else
 {
    $filtr_name_url=$Url->a('СЕТЬ', a=>'payshow', act=>'list_categories');
 }

 # area_ - поля в виде редактирования
 # html_ - поля в виде просмотра

 $area_reason = "<br><textarea rows=5 cols=50 name=reason id=reason>".v::filtr($orig_reason)."</textarea>";
 $area_comment = "<br><textarea rows=5 cols=50 name=comment id=comment>".v::filtr($orig_comment)."</textarea>";
 $area_bonus='';

 $html_reason=$orig_reason;
 $html_comment=$orig_comment;
 $html_bonus='';

 $reason_title='Комментарий';

 {
  if ($type==10)
  {
     $need_money=1;
     if ($mid>0)
       {
        $nm_pay='Платеж клиента';
        $html_bonus=' <span class=data1>безнал</span>' if $bonus;
        $area_bonus="<input type=checkbox name=bonus value=y style='border:1;'".(!!$bonus && ' checked')."> безнал";
        $reason_title='Комментарий для администратора';
        $comment_title='Комментарий, который видит клиент';
        last if Adm->chk_privil('pays_create');
        $logm.='<li>У вас нет прав на проведение платежей клиентов, поэтому редактирование данной записи вам недоступно.</li>';
        $can_edit=0;
        last;
       }
     $comment_title='Дополнительный комментарий';
     if ($mid)
       {
        $nm_pay='Выдача наличных работнику';
        $logm.='<li>У вас нет прав на проведение зарплат работников, поэтому редактирование данной записи вам недоступно.</li>';
       }else
       {
        $nm_pay=&commas('Затраты сети');
        $logm.='<li>У вас нет прав на проведение затрат сети, поэтому редактирование данной записи вам недоступно.</li>';
       }
     $can_edit=0;
     last;
  }

  if ($type==20)
  {
     $need_money=1;
     $nm_pay='Временный платеж';
     $area_bonus=v::input_h('bonus','y');
     $reason_title='Комментарий для администратора';
     $comment_title='Комментарий, который видит клиент';
     last if Adm->chk_privil('tmp_pays_create');
     $logm.='<li>У вас нет прав на проведение временных платежей, поэтому редактирование данной записи вам недоступно.</li>';
     $can_edit=0;
     last;
  }

  if ($type==30)
  {
     $need_money=0;
     $comment_title='Сообщение';
     if ($mid)
       {
        $nm_pay='Сообщение';
        last if Adm->chk_privil('mess_create');
        $logm.='<li>У вас нет прав на отправку сообщений клиентам, поэтому редактирование данной записи вам недоступно.</li>';
       }else
       {
        $nm_pay='Многоадресное сообщение';
        last if Adm->chk_privil('mess_all_usr');
        $logm.='<li>У вас нет прав на отправку многоадресных сообщений, поэтому редактирование данной записи вам недоступно.</li>';
       }
     $can_edit=0;
     last;
  }

  if ($type==40)
  {
     $need_money=1;
     $area_bonus=v::input_h('bonus','y');
     $nm_pay='Передача наличных';
     if ($can_edit)
       {
        if ($category!=470 && !Adm->chk_privil('SuperAdmin'))
          {
           $can_edit=0;
           $logm.='<li>Изменение платежа заблокировано, поскольку данный тип платежа является переводом наличности от одного администратора другому. '.
              'При этом админ-получатель принял решение по поводу (не)действительности данного платежа. Платеж может удалить/изменить только суперадмин.</li>';
          } 
        if( !Adm->chk_privil(19) )
        {
           $can_edit=0;
           $logm.='<li>У вас нет прав на оформление передач наличных, поэтому редактирование данного платежа вам недоступно.</li>';
        }
       }

     $r=int $orig_reason; # id админа
     $c=int $orig_comment; # id админа

     $reason_title='Админ передающий наличные';
     $comment_title='Админ принимающий наличные';

     # Получим выпадающее меню админов
     $area_reason=$br2.'<select size=1 name=reason>';
     $area_comment=$br2.'<select size=1 name=comment>';
     $sth= Db->("SELECT * FROM admin ORDER BY login");
     while( my %p = $sth->line )
    {
        $login=$p{login};
        $id=$p{id};
        $area_reason.="<option value=$id".($r==$id? ' selected':'').">$login</option>";
        $area_comment.="<option value=$id".($c==$id? ' selected':'').">$login</option>";
        $html_reason=$login if $r==$id;
        $html_comment=$login if $c==$id;
    }
     $area_reason.='</select>';
     $area_comment.='</select>';
     last;
  }

  if ($type==50)
  {
     $need_money=0;
     $nm_pay='Событие';
     if( $can_edit && !Adm->chk_privil('SuperAdmin') )
     {
        $can_edit=0;
        $logm.='<li>У вас нет прав на редактирование событий.</li>';
     }
     $reason_title='Данные события';
     $comment_title='Дополнительный комментарий';
     last;
  }

  $nm_pay="неизвестный тип платежа, код: $type";
  $need_money=1;
 }

 if( $can_edit && $ct_block_edit{$category} && !Adm->chk_privil('SuperAdmin') )
 {
    $logm.='<li>Категория записи разрешает редактирование только суперадмину</li>';
    $can_edit=0;
 } 
}

# =======================================
#	Форма изменения платежа
# =======================================

sub pay_show
{
 get_pay_data();
 if( $can_edit && !Adm->chk_privil('edt_old_pays') )
 {
    $t_blk=$t_pay - $ses::t + 600;
    if ($t_blk<0)
    {
       $can_edit=0;
       $logm.='<li>Со времени создания записи прошло более 10 минут.<br>Привилегии вашей учетной записи не позволяют редактировать записи старее этого времени.</li>';
    }
     elsif ($t_blk<600)
    {
       $logm.="<li>Через ".($t_blk>=60 && int($t_blk/60).' мин ').sprintf("%02d",$t_blk % 60).' сек'.
       ' редактирование платежа будет <span class=error>заблокировано</span>.</li>';
    }
 }

 $out2='';
 $out1=$logm && &RRow('*','L',"<ul>$logm</ul>");
 $out1.=&RRow('*','ll','Тип',$nm_pay);
 $out1.=&RRow('*','ll',"Категория <span class=disabled>($category)</span>",$ct{$category}) if $ct{$category};
 $out1.=&RRow('*','ll','С кем связан',$filtr_name_url).
   &RRow('*','ll','Время занесения',$pay_time).
   &RRow('*','ll','Автор',$display_admin).
   &RRow('*','ll','Имя автора',$adm_name);
 $out1.=&RRow('*','ll','Сумма платежа',v::bold($cash)." $gr$html_bonus") if $need_money;

 $reason_title=$ct_name_fields{$category}[0] if $ct_name_fields{$category}[0];
 $comment_title=$ct_name_fields{$category}[1] if $ct_name_fields{$category}[1];

 if ($category_subs{$category})
   {# в данной категории есть расшифровка поля reason
    ($mess,$error_mess)=&{$category_subs{$category}}($orig_reason,$orig_comment,$t_pay,$mid);
    $html_reason=$mess && &div('message',$mess);
    $reason_title='Закодированые данные';
   }else
   {
    $html_reason=($html_reason ne '') && v::bold($reason_title).&div('message',$html_reason);
   }

 $out1.=&RRow('*','L',$html_reason) if $html_reason ne '';
 $out1.=&RRow('*','L',v::bold($comment_title).&div('message',$html_comment)) if $html_comment ne '';

 if ($can_edit)
   {
    $out=$need_money? &RRow('*','ll','Сумма платежа',v::input_t(name=>'cash',value=>$cash)." $gr$area_bonus") : v::input_h('cash',0);
    $h=$ct_decode_mess{$category};
    if ($h)
      {
       $h=~s|#|<br>|g;
       $h=~s|\{(.+?)\}|<span class='data1 big'>$1</span>|g;
       $area_reason.=&div('story bordergrey',$h)
      }
    $area_reason.=&div('message lft',"<span class=error>Закодированные данные искажены</span>:".$br2.$error_mess) if $error_mess;
    $out.=&RRow('*','C',v::bold($reason_title).$area_reason);
    $out.=&RRow('*','C',v::bold($comment_title).$area_comment);
    $out2.=&form('!'=>1,'id'=>$Fid,'act'=>'edit',
      Table('tbg3',
        $out.
        &RRow('*','ll','<span class=error>Удалить запись</span>',"<input type=checkbox name=del value=1 style='border:1;'>").
        (!!Adm->chk_privil('SuperAdmin') && &RRow('*','ll','Не регистрировать событие об изменении записи',"<input type=checkbox name=dontmark value=1 style='border:1;'>")).
        &RRow('*','C','<br>'.v::submit('Изменить запись').'<br>')
      )
    );
   }else
   {
    $out2.=&form('!'=>1,'id'=>$Fid,'act'=>'plzedit',
      &Table('tbg3',
       &RRow('*','l','Вы можете послать ответственному администратору сообщение с просьбой отредактировать/удалить данную запись. Ниже укажите причину:').
       &RRow('*','c','<textarea rows=7 cols=38 name=reason></textarea>').
       &RRow('*','c',v::submit('Отослать'))
      )
    ).'<br>';
   }

 Show div('message cntr',&Table('','<tr><td valign=top width=50%>'.&Table('tbg3',$out1)."</td><td valign=top>$out2</td></tr>"));
}

# ===========================================
# Непосредственное изменение/удаление платежа
# ===========================================

sub pay_edit
{
&get_pay_data;
$can_edit or &Error("Вы не можете изменить запрошенный платеж, причина: <ul>$logm</ul>");

&Error("Со времени создания записи прошло более 10 минут. Привилегии вашей учетной записи не позволяют редактировать записи старше 10 минут.".$br2.
        v::bold('Запись не изменена.')) if !Adm->chk_privil('edt_old_pays') && $t_pay<($ses::t-600);

$ClientPaysUrl = "$scrpt&a=payshow".($mid? "&uid=$mid" : '&nodeny='.($type==50? 'event': $type==30? 'mess': 'net'));

{
 # не создаем событие об изменении записи если запросил админ либо для избежания замкнутого круга: удаление/редактирование события -> создние события
 $dont_mark=($F{dontmark} && Adm->chk_privil('SuperAdmin')) || $category==502 || $category==501; 
 last if $dont_mark;
 # Создадим платеж "измененная запись", которая будет являться старым вариантом для изменяемой записи
 $sql="INSERT INTO pays SET mid=$mid,type=50,category=501,cash=0,bonus='',".
   "creator_id=$adm_id,creator_ip=INET_ATON('$admin_ip'),time=$t_pay,comment='".Db->filtr($orig_comment)."',".
   "reason='$Fid:$type:$category:$cash:$bonus:".Db->filtr($orig_reason)."'";
 $sth = $dbh->prepare($sql);
 $sth->execute;
 $iid = $sth->{mysql_insertid} || $sth->{insertid};
 debug(
    _('[span data2][br][][br]Запрос []',
       'Создаем копию записи - это будет старый вариант записи',$sql,$iid? "выполнен. INSERT_ID=$iid" : v::bold('не выполнен')
    )
 );
 $iid or Error("Произошла внутренняя ошибка. Данные не изменены.");
}

{
 $F{del} or last;
 # Удаление платежа
 $rows = Db->do("DELETE FROM pays WHERE id=$Fid LIMIT 1");
 if( $rows<1 || Db->line("SELECT * FROM pays WHERE id=$Fid LIMIT 1") )
 {
    $dont_mark or Db->do("DELETE FROM pays WHERE id=$iid LIMIT 1");
    Error("Внутренняя ошибка. Запись с id=$Fid не удалена.");
 }

 #ToLog("$Adm->{info_line} Удалил запись id=$Fid из таблицы платежей. mid=$mid, bonus=$bonus, cash=$cash, time=$pay_time, type=$type, category=$category");

 if( !$dont_mark )
 {
    Pay_to_DB( mid => $mid, type => 50, category => 502, reason => "$iid:0" );
 }

 if ($mid>0 && $need_money && $cash!=0)
   {
    $rows=Db->do("UPDATE users SET balance=balance-($cash) WHERE id=$mid LIMIT 1");
    if ($rows<1)
      {
       #ToLog("! $Adm->{info_line} После удаления платежа произошла ошибка изменения баланса клиента. Необходима ручная корректировка");
       Error("Запись удалена из таблицы платежей, однако при изменении баланса клиента произошла ошибка! Необходимо ручная корректировка главным администратором.");
      }
   }

 Db->do("INSERT INTO changes SET tbl='pays',act=2,time=$ses::t,fid=$Fid,adm=".Adm->id);

 Show MessageBox('Запись удалена из таблицы платежей.'.$br2.&ahref($ClientPaysUrl,'Смотреть платежи'));
 return;
}

# =====================
# Редактирование записи

$F{reason}=~s/(\s+|\n)$//; # уберем финальные проблеы и переводы строк
$F{comment}=~s/(\s+|\n)$//;                                           

$new_reason=Db->filtr($F{reason});
$new_comment=Db->filtr($F{comment});
$new_cash=sprintf("%.2f",$F{cash}+0);
$new_category=$category;

{
 # поскольку категория для платежа зависит от нал/безнал, положительный/отрицательный
 # переведем категорию в "запись редактировалась" (9 - для положительный бонус, 109 - отрицательный бонус, 609 - положительный нал, 709 - отриц. нал)
 if( $type==10 )
 {  # платеж
    if( $mid>0 )
    {# клиента
      $new_bonus=$F{bonus}? 'y':'';
      $new_category=$new_bonus? 9 : 609;
    }else
    {
      $new_bonus='';
      $mid && $new_cash>0 && &Error("В выдаче наличных работникам не допускается положительная сумма платежа!");
      $new_category=$mid? 809 : 209;
    }
    $new_category+=100 if $new_cash<=0;
    last;
 }

 if( $type==20 )
 {  # временный платеж только безналом
    $new_bonus='y';
    last;
 }

 if( $type==30 )
 {  # сообщение
    $new_bonus='';
    $new_cash=0;
    $new_reason=Db->filtr($orig_reason) unless $mid; # нельзя менять список групп клиентов в многоадресном сообщении (доступы к группам...)
    last;
 }

 if( $type==40 )
 {  # передача наличных только безналом
    $new_bonus='y';
    $new_reason=int $new_reason;
    $new_comment=int $new_comment;
    $new_category=470; # уберез подтверждение передачи, поскольку данные трансфера изменились
    last;
 }

 # событие или неизвестный тип платежа
 $new_bonus='';
 $new_cash=0;
}

$sql="UPDATE pays SET cash=$new_cash,bonus='$new_bonus',reason='$new_reason',comment='$new_comment',category=$new_category WHERE id=$Fid LIMIT 1";
$rows = Db->do($sql);
if( $rows<1 )
{
   $dont_mark or Db->do("DELETE FROM pays WHERE id=$iid LIMIT 1");
   Error("Внутренняя ошибка. Запись не изменена.");
}

if( !$dont_mark )
{
   Pay_to_DB( mid => $mid, type => 50, category => 502, reason => "$iid:$Fid" );
}

#ToLog("$Adm->{info_line} Изменена запись id=$Fid в таблице платежей.");
  
if ($mid<=0 || !$need_money || $new_cash==$cash)
{
   Show MessageBox('Изменения сохранены.'.$br2.&ahref($ClientPaysUrl,'Смотреть платежи'));
   return;
}

# Изменим баланс клиента
$rows=Db->do("UPDATE users SET balance=balance+($new_cash)-($cash) WHERE id=$mid LIMIT 1");
if( $rows<1 )
{
   #ToLog("! $Adm->{info_line} После изменения платежа произошла ошибка изменения баланса клиента. Необходима ручная корректировка.");
   Error("Запись изменена, однако при изменении баланса клиента произошла ошибка! Необходимо ручная корректировка главным администратором.");
}

 Show MessageBox('Изменения сохранены.'.$br2.&ahref($ClientPaysUrl,'Смотреть платежи'));
}

# ===========================================
#        Просьба изменить платеж
# ===========================================
sub plz_edit
{
 &get_pay_data;
 $reason=Db->filtr($F{reason});
 my %p = Db->line("SELECT FROM pays WHERE mid=$mid AND category=417 AND reason='p:$Fid' AND comment='$reason' LIMIT 1");
 %p && Error("Запрос уже сформирован. Вероятно вы послали его дважны.");
 $p = \%p;
 $sql="INSERT INTO pays (mid,cash,type,category,creator_id,creator_ip,reason,comment,time) ".
      "VALUES($mid,0,50,417,".Adm->id.",INET_ATON('$ses::ip'),'p:$Fid','$reason',unix_timestamp())";
 $rows = Db->do($sql);
 $rows<1 && Error("Временная ошибка. Повторите запрос позже.");
 Show MessageBox("Послан запрос на изменение платежа с id=$Fid. Ожидайте реакции ответственного администратора.");
}

# ===========================================
#	Пометить запись как `ответ дан`
# ===========================================
sub mark_answer
{
 &get_pay_data;
 $can_edit or Error("Вы не можете изменить запрошенный платеж.");
 Adm->chk_privil('SuperAdmin') or Error('Недостаточно привилегий.');
 $rows=Db->do("UPDATE pays SET category=492 WHERE id=$Fid AND type=30 AND category=491 LIMIT 1");
 $rows=$rows==1? 'Сообщение помечено кодом `ответ дан`' : "Никаких действий не производилось - установка признака сообщения `ответ дан` не требуется";
 Show MessageBox($rows);
}

# ============================================================
#
#		Пополнение счета/Отправка сообщений
#
# ============================================================

sub pay_now
{
  $reason = trim(Db->filtr($F{reason}));
 $comment = trim(Db->filtr($F{comment}));
 $Fop=$F{op};
 $mss_log='';
 $time=$ses::t;
 $category=0;

 if( $Fmid>0 )
 {
    my $p = Get_usr_info($Fmid);
    $user_info = $p->{full_info};
    $grp = $p->{grp};
    $mId = $Fmid;
    $mId or Error("Клиент с id=$Fmid не найден в базе данных.");
    $Fmid = $mId;
    Adm->chk_usr_grp($grp) or Error("Клиент находится в группе, к которой у вас нет доступа.");
    $ClientPaysUrl="$scrpt&a=payshow&uid=$Fmid";
 }

 if( $Fop eq 'mess' || $Fop eq 'cmt' )
 {
    $comment=~/^\s*$/ && &Error("Сообщение не создано т.к вы не ввели текст сообщения.");
    $Fmid<0 && &Error("Нельзя отправлять сообщения работникам.");
    if( $Fmid )
    {
       Adm->chk_privil('mess_create') or Error('Вам не разрешено посылать сообщения клиентам либо оставлять комментарии.');
       $reason='';
       if ($Fop eq 'mess')
       {
            $Fq=int $F{q}; # id сообщения, которое цитировалось.
            if( $Fq )
            {
                my %p = Db->line("SELECT id FROM pays WHERE id=$Fq AND mid=$Fmid AND type=30 AND category IN (491,492)");
                $reason = $Fq if %p;
            }
            $pay_made_mess='Сообщение сохранено.';
            $category = 480;
       }else
       {
          $reason=$comment;
          $comment='';
          $pay_made_mess='Замечание клиенту сохранено.';
          $category=495;
       }
    }
     else
    {
        Adm->chk_privil('mess_all_usr') or Error('У вас нет прав на многоадресную отправку сообщений.');
        $ClientPaysUrl="$scrpt&a=payshow&nodeny=mess";
        $reason=''; # в этом поле через запятую будут перечислены номера групп клиентов для которых идет отправка сообщения
        foreach( keys %{Ugrp->hash} )
        {
            $reason.="$_," if $_ && Adm->chk_usr_grp($_) && $F{"g$_"};
        }
        if( !$reason )
        {
            $comment=$comment!~/^\s*$/ && $br2.'Введенное вами сообщение:'.$br.v::input_ta('comment',$F{comment},50,8);
            Error("Вы не выбрали ни одну группу клиентов, для которой отправляете сообщение.".$comment);
        }
        $reason=",$reason"; # для поиска по шаблону, список должен быть обрамлен запятыми по краям
        $pay_made_mess='Многоадресное сообщение сохранено.';
        $category = 485;
    }
    $type=30; # тип платежа - сообщение
    $bonus='';
    $cash=0;
 }
  else
 {  # Платеж, а не сообщение
    $cash = sprintf("%.2f",$F{cash}+0);
    $cash==0 && Error("Не указана сумма платежа! Платеж не проведен"); # ! не unless $cash
    if( $Fmid>0 )
    {
      if( $Fop eq 'tmp' )
      {  # временный платеж
         Adm->chk_privil('tmp_pays_create') or Error('Вам не разрешено осуществлять временные платежи.');
         $Fdays=int $F{days};
         $Fdays<=0 && &Error('Не выбран срок временного платежа.');
         $reason=$ses::t;
         $time=$ses::t+$Fdays*3600*24;
         $pay_made_mess="Временный платеж $cash $gr проведен.";
         $type=20;
         $bonus='y';
         $category=1000;
      }
       elsif( $Fop eq 'old' )
      {  # платеж задним числом
         Adm->chk_privil('old_pays_create') or Error("Вам не разрешено проводить платежи `задним числом`.");
         $Fmon=int $F{mon};
         $Fyear=int $F{year};
         $Fday=int $F{day};
         ($Fday<0 || $Fmon<1 || $Fmon>12 || $Fyear<1990 || $Fyear>2100) && &Error('Ваш диск успешно отформатирован. Продолжить?');
         $max_day=&GetMaxDayInMonth($Fmon,$Fyear-1900);
         ($Fday<1 || $Fday>$max_day) && Error('День задан неверно! Платеж задним числом не проведен.');
         $pay_made_mess="Платеж задним числом проведен.";
         $time=timelocal(15,0,12,$Fday,$Fmon-1,$Fyear-1900); # в 12:00
         if ($time<$Tnt_timestamp)
         {  # неактуальный платеж
            Adm->chk_privil(53) or Error('Дата платежа ниже разрешенной граничной отметки! У вас должны быть права проведения неактуальных платежей.');
            $bonus='y';
            $category=$cash>0? 80 : 180; # `неактуальный платеж`
            $reason = $ses::t.':'.$reason;
         }
          elsif ($time>$ses::t)
         {
            &Error('Будущим числом платежи не разрешено проводить.');
         }
          else
         {
            $bonus=$F{bonus}? 'y':'';
            !$bonus && ($category=$cash>0? 600 : 700); # `наличный платеж`
            $reason="Платеж введен задним числом $ses::time_now".(!!$reason && "\n\n$reason");
         }
         $type=10;
      }
       else
      {
            Adm->chk_privil('pays_create') or Error('Вам не разрешено осуществлять обычные платежи');
            Error('Не разрешено проводить безналичные пополнения без комментариев. Укажите причину, например, '.
                "`поощрение за...`, `по акции за...` и т.д.") if $Block_bonus_pay && $F{bonus} && !($reason || $comment);
         $pay_made_mess="Платеж $cash $gr проведен.";
         $type=10;
         $bonus=$F{bonus}? 'y':'';
         !$bonus && ($category=$cash>0? 600 : 700); # `наличный платеж`
      } 
    }
     elsif( $Fmid<0 )
    {
       Error('Вам не разрешено производить операции с зарплатами работников.');
    }
     elsif( Adm->chk_privil('net_pays_create') )
    {
       $ClientPaysUrl="$scrpt&a=payshow&nodeny=net";
       $pay_made_mess="Платеж $cash $gr затрат сети проведен.";
       $type=10;
       $bonus='';
    }
     else
    {
       &Error('Вам не разрешены операции по добавлению/снятию наличных с сети.');      
    }
 }

 $sql="INSERT INTO pays (mid,cash,type,time,creator_id,creator_ip,bonus,reason,comment,category) ".
      "VALUES($Fmid,$cash,$type,$time,".Adm->id.",INET_ATON('$ses::ip'),'$bonus','$reason','$comment',$category)";
 $sth=$dbh->prepare($sql);
 $sth->execute;
 $iid=$sth->{mysql_insertid} || $sth->{insertid}; # id только что внесенной записи

 my %p = Db->line("SELECT * FROM pays WHERE id=$iid");
 if( !$iid || !%p || $cash != sprintf("%.2f",$p{cash}) )
 {
    &Error("Произошла ошибка при добавлении записи в таблицу платежей.".$br2.
      "После выполнения запроса была запрошена сумма и результат не был получен либо сумма не совпала.");
 }

 $state_off='';

 # обновим баланс клиента
 if ($Fmid>0 && $cash!=0)
 {
    $rows=Db->do("UPDATE users SET balance=balance+$cash WHERE id=$Fmid LIMIT 1");
    if ($rows<1)
    {
       &ToLog("После осуществления платежа произошла ошибка изменения баланса клиента id=$Fmid. Проверьте баланс по платежам, вероятно необходима ручная корректировка");
       &Error($pay_made_mess.$br2."Ошибка при изменении баланса клиента!$br2<b>Внимание:</b> вероятно необходима ручная корректировка баланса главным администратором.");
    }
    my %p = Db->line("SELECT * FROM users WHERE id=$Fmid LIMIT 1");
    %p or &Error("Платеж проведен, однако произошла ошибка при проверке данных клиента.");
    $p = \%p;
    $balance=$p->{balance};
    $paket=$p->{paket};
    $srvs=$p->{srvs};
    $start_day=$p->{start_day};
    $discount=$p->{discount};
    $limit_balance=$p->{limit_balance};
    # Проверим, отключен ли юзер имея положительный баланс или баланс выше границы отключения.
    # Если да, то напомним, что неплохо бы включить (или сами включим если настроки указывают)
    # Не забываем что может быть ситуация когда основная запись включена, а алиасная выключена
    {
      $p->{block_if_limit} or last;
      my %p = Db->line("SELECT * FROM users WHERE (id=$Fmid OR mid=$Fmid) AND state='off' LIMIT 1");
      %p or last;
      $p = \%p;
      # как минимум одна из записей клиента заблокирована. Вычислим сколько будет на счету в конце месяца
sub GetClientTraf
{
 my %p = Db->select_line("SELECT * FROM users_trf WHERE uid=? LIMIT 1", $_[0]);
 %p or return(0,0,0,0,0,0,0,0);
 return($p{in1},$p{out1},$p{in2},$p{out2},$p{in3},$p{out3},$p{in4},$p{out4});
}
      @T=&GetClientTraf($Fmid);

      $rez_balance = $balance;
      $block_balance = $rez_balance;
      last if $block_balance<$limit_balance;
      if( $auto_on==2 )
      {  # разрешим доступ
         Db->do("UPDATE users SET state='on' WHERE id=$Fmid OR mid=$Fmid");
         $pay_made_mess.=$br2.'Доступ в интернет разрешен - баланс выше установленного лимита.';
         $state_off=" После осуществления платежа доступ в интернет был открыт";
      }else
      {
         $pay_made_mess.=$br2.'Не забудьте разрешить доступ в интернет - баланс выше установленного лимита.';
         $state_off=" Необходимо включить доступ в интернет";
      }
    }

    $pay_made_mess.=$br2."Обновление баланса клиента выполенено успешно: ".v::bold($balance)." $gr";
    $mss_log="Счет клиента id=$Fmid пополнен на $cash $gr ";
    $mss_log.=" (платеж временный, срок действия $Fdays дней)" if $type==20;
    $mss_log.=". Текущий баланс клиента $balance $gr.$state_off";  
 }

 if( $cash!=0 )
 {
    if( !$Fmid )
    {
       $mss_log="Проведено $cash $gr как платеж на сеть.";
       $mss_log.=" Комментарий к записи: $reason" if $reason;
    }elsif( $Fmid<0 )
    {
       $mss_log="Выдана зарлата (аванс) работнику № $wid в размере на $cash $gr.";
       $mss_log.= "Комментарий к записи: $reason" if $reason;
    }
 }
  elsif( $Fop eq 'mess' && $Fq )
 {
    Db->do("UPDATE pays SET category=492 WHERE id=$Fq AND type=30 AND mid=$Fmid AND category=491 LIMIT 1");
 }

 #ToLog("$Adm->{info_line} $mss_log") if $mss_log && $AllToLog;

 Show div( 'infomess lft',$pay_made_mess.&Table('table2 nav',&RRow('','ll',$br2.&ahref($ClientPaysUrl,'Смотреть платежи'),'')) );
 Doc->template('top_block')->{header}.=qq{<meta http-equiv='refresh' content='10; url="$ClientPaysUrl"'>};
}

# =========================================================
#	Передача наличных от одного админа другому
# =========================================================
sub send_money
{
 Adm->chk_privil('transfer_money') or Error('Нет прав для передачи наличных между администраторами.');
 Adm->get();
 $A = $Adm::adm;
 $cash=sprintf("%.2f",$F{cash}+0);
 if( $cash!=0 )
 {
    $cash<0 && &Error("<b>Передача денег не осуществлена</b>: сумма наличности должна быть положительным числом.");

    $from=int $F{from};
    $to=int $F{to};

    defined($A->{$from}{admin}) or &Error("Передача денег не осуществлена: админа с id=$from нет в списке администраторов.");
    defined($A->{$to}{admin}) or &Error("Передача денег не осуществлена: админа с id=$to нет в списке администраторов.");

    ($to==$from) && &Error("Передача денег не осуществлена: получатель и отправитель одно и тоже лицо.");

    $Apay_sql = "creator_id=".Adm->id.",creator_ip=INET_ATON('$ses::ip')";
    $sql="INSERT INTO pays SET $Apay_sql,mid=0,cash=$cash,type=40,bonus='y',category=470,reason='$from',comment='$to',time=unix_timestamp()";

    $_=Digest::MD5->new;
    $param_hash=$_->add($sql)->b64digest;
    $Ftime=int $F{time};
    $Frand=int $F{rand};

    $href=$br3.&CenterA("$scrpt&a=payshow&nodeny=transfer",'Далее &rarr;');

    my %p = Db->line("SELECT * FROM changes WHERE tbl='pays' AND act=1 AND time=$Ftime AND fid=$Frand AND adm=".Adm->id." AND param_hash='$param_hash'");
    %p && Error("Обнаружена повторная посылка данных. Вероятно вы обновили страницу. Передача наличных была осуществлена ранее.".$href);
    $rows=Db->do($sql);
    Show div('message cntr',$br2.v::bold('Передача денег ').
        ($rows<1? '<span class=error>не осуществлена</span>' : v::bold('осуществлена')).$href
    ).$br;

    $rows>0 && Db->do("INSERT INTO changes SET tbl='pays',act=1,time=$Ftime,fid=$Frand,param_hash='$param_hash',adm=".Adm->id);
    return;
 }
 # вывод формы передачи наличных
 $AdminsList='';
 foreach $id (keys %$A)
 {
    next if $A->{$id}{privil}!~/,62,/; # 62 - админ может участвовать в передачах
    $AdminsList.="<option value=$id>$A->{$id}{admin}</option>";
 }
 # time и rand - признаки повторной посылки данных
 Show form('!'=>1,'act'=>'send','time'=>$ses::t,'rand'=>int(rand 2**32),
    &Table('',&RRow('','ttt',
      'Админ, передающий наличные'.$br."<select name=from size=20>$AdminsList</select>",
      $br.'Передаваемая сумма'.$br2.v::input_t(name=>'cash').' '.$gr.$br2.
      v::submit('Выполнить'),
      'Админ, принимающий наличные'.$br."<select name=to size=20>$AdminsList</select>"
    ))
 );
}

# ------------------------------------------
#  Многоадресная отправка сообщений
# ------------------------------------------

sub mess_for_all
{
 Adm->chk_privil(34) or Error('У вас нет прав на многоадресную отправку сообщений.');

 $out='Выберите группы клиентов,<br>для которых необходимо отправить<br>многоадресное сообщение:'.$br2;
 foreach( Ugrp->list )
 {
    $out.="<input type=checkbox value=1 name=g$_> ".Ugrp->grp($_)->{name}.$br;
 }
 $out2=&Table('nav2',&RRow('','ll',&ahref('#','Выделить все группы',qq{onclick="SetAllCheckbox('grp',1); return false;"}),
    &ahref('#','Снять выделение',qq{onclick="SetAllCheckbox('grp',0); return false;"}))).
    $br2.'Сообщение:'.$br.v::input_ta('comment','',44,7).$br2;

 $out=&Table('table10',&RRow('','^^',"<div id=grp>$out</div>",$out2.v::submit('Отправить!')));
 Show $br.&form('!'=>1,'#'=>1,'act'=>'pay','op'=>'mess','id'=>0,MessageBox($out));
}

sub set_block
{# установка блокировок для клиента
 %f=(
   'mess'	=> [Adm->chk_privil(55),451,'Нет прав на отправку/блокировку сообщений.','Вы заблокировали возможность отправки клиентом сообщений администрации через клиентскую статистику'],
   'packet'	=> [Adm->chk_privil(117),450,'Нет прав на установку блокировки для клиента на заказ пакета через клиентскую статистику.','Вы заблокировали возможность клиенту заказать пакет через клиентскую статистику'],
 );

 defined $f{$F{what_block}} or &Error('Неверная команда. Действие не выполнено.');

 ($priv,$category,$mess1,$mess2)=@{$f{$F{what_block}}};

 $priv or &Error($mess1);

 my $p = Get_usr_info($Fmid);
 $grp = $p->{grp};
 $mId = $Fmid;
 $mId or &Error("Клиент с id=$Fmid не найден в базе данных.");
 Adm->chk_usr_grp($grp) or &Error("У вас нет прав на работу с учетной записью указанного клиента.");

 my %p = Db->line("SELECT * FROM pays WHERE mid=$mId AND type=50 AND category=$category LIMIT 1");
 %p && Error("Для данного клиента уже существует заказанная блокировка. Возможно вы продублировали запрос.");

 Pay_to_DB( mid => $mId, type => 50, category => $category );
 $url="$scrpt&a=payshow&mid=$mId";
 Show MessageBox("$mess2. Отменить блокировку сможет администратор с правами редактирования событий - он должен будет удалить в платежах клиента соответствующее событие-блокировку.".$br2.
         &CenterA($url,'Смотреть платежи/события клиента'));
 Doc->template('top_block')->{header}.=qq{<meta http-equiv="refresh" content="15; url='$url'">};
}

# ------------------------------------------
#     Форма для осуществления платежей
# ------------------------------------------

sub payform_show
{
 $cash = $F{cash}+0;
 $comment = v::input_ta('comment',$F{comment},44,7);

 $out='';

 if( $Fmid<0 )
 {
   Adm->chk_privil('worker_pays_create') or Error('Нет прав на выдачу зарплат/авансов.');
   $wid=-$Fmid;
   $W = {};
   defined($W->{$wid}) or &Error("Работник № $wid не найден в базе данных.");
   $user_info=MessageBox("Имя работника: ".$W->{$wid}{url}.$br."Должность: ".v::bold($W->{$wid}{post}));
   $out.=v::input_h('mid'=>$Fmid,'comment'=>'').
      "Введите сумму которую начисляете в счет зарплаты/аванса работнику".$br2.
      v::input_t(name=>'cash', value=>$cash, id=>'cash')." $gr".$br2.
      v::bold('Комментарий').$br.v::input_ta('reason',$F{reason},44,7);
    Doc->template('top_block')->{body_tag} .=qq { onload="javascript: document.getElementById('cash').focus();"};
 }
  elsif ($Fmid)
 {
    my $p = Get_usr_info($Fmid);
    $user_info = $p->{full_info};
    $grp = $p->{grp};
    $mId = $Fmid;
    $mId or Error("Клиент с id=$Fmid не найден в базе данных.");
    Adm->chk_usr_grp($grp) or &Error("У вас нет прав на работу с записью клиента.");
    $user_info=MessageBox($user_info);
    $out.=v::input_h('mid',$mId);

    (Adm->chk_privil('pays_create') || Adm->chk_privil('tmp_pays_create') || Adm->chk_privil('old_pays_create') || Adm->chk_privil('mess_create')) or
        Error("Вам не разрешено проводить никакие типы платежей/сообщений клиентам.");

   @f=();
   push @f,['pay',1,'обычный платеж'] if Adm->chk_privil('pays_create');
   push @f,['tmp',1,'временный платеж'] if Adm->chk_privil('tmp_pays_create');
   push @f,['old',1,'платеж задним числом'] if Adm->chk_privil('old_pays_create');
   push @f,['mess',0,'сообщение клиенту'] if Adm->chk_privil('mess_create');
   push @f,['cmt',0,'комментарий к учетной записи'] if Adm->chk_privil('mess_create');
   $Fop=$F{op}||'pay';
   $hide_cod=qq{\$("#comment_div").hide(); \$("#cash_div").hide(); };
   $hide_cod.=qq{\$("#$_->[0]").hide(); } foreach @f;
   Show "<script>function hide_e() { $hide_cod }</script>";
   foreach( @f )
   {
      $h=qq{hide_e(); document.getElementById("$_->[0]").style.display=""; };
      $h.=qq{document.getElementById("comment_div").style.display=""; }.
          qq{document.getElementById("cash_div").style.display="";} if $_->[1];
      $out.="<input type=radio id=radio$_->[0] value=$_->[0] name=op style='border:0;' ".($Fop eq $_->[0] && 'checked ').
        qq{onClick='$h'><label for=radio$_->[0]>$_->[2]</label>}.$br;
   }

   $mon_list = Set_mon_in_list($ses::mon_now);
   $year_list = Set_year_in_list($ses::year_now);
   $day_list='<select size=1 name=day><option value=0>&nbsp;</option>'.
      (join '',map {"<option value=$_>$_</option>"}(1..31))."</select> $mon_list $year_list".$br;

   $opMess=$Fop eq 'mess';
   $out.=$br.'<div id=cash_div'.($opMess && " style='display:none'").'>'.
        v::tag('input', type=>'text', name=>'cash', size=>$cash, maxlength=>14, id=>'cash', autocomplete=>'off')." $gr ".
        "<input type='checkbox' name='bonus' value='1' > безнал".$br2.
   '</div>';

   if( Adm->chk_privil('pays_create') )
   {
      $out.="<div id=pay".($opMess && " style='display:none'").'>'.v::bold('Комментарий для админов').'</div>';
   }

   if( Adm->chk_privil('tmp_pays_create') )
   {
      $out.="<div id=tmp ".($Fop ne 'tmp' && "style='display:none'").'>'."Временный платеж на ".
        "<select size=1 name=days>".(join '',map {"<option value=$_>$_</option>"}(1..31))."</select> дней".$br3.
        v::bold('Комментарий для админов').
      '</div>';
   }

   if( Adm->chk_privil('old_pays_create') )
   {
      $out.="<div id=old style='display:none'>Провести платеж следующей датой: ".$br2.
        $day_list.$br2.v::bold('Комментарий для админов').
      '</div>';
   }

   if( Adm->chk_privil('mess_create') )
   {
        $Fq=int $F{q}; # id сообщения клиента, на которое дается ответ
        if ($Fq)
        {
            my %p = Db->line("SELECT reason FROM pays WHERE id=$Fq AND mid=$Fmid AND type=30 AND category IN (491,492)");
            $Fq=0 unless %p;
        }
        $out.='<div id=mess'.(!$opMess && " style='display:none'").'>'.$br2.(!$Fq? v::bold('Сообщение') :
            v::input_h('q'=>$Fq).'Вы отвечаете на сообщение клиента: '.&div('message',$p->{reason})).
        '</div>';
        $out.="<div id=cmt style='display:none'>".$br2.v::bold('Комментарий').'</div>';
   }

   $out.='<div id=comment_div'.($opMess && " style='display:none'").'>'.
        v::input_ta('reason',$F{reason},44,5).$br.
       v::bold('Комментарий, который будет видеть клиент ').
   '</div>';

   $out.=$comment;
   $pay_mess='';
   # ИСПРАВИТЬ $p_adm не существует
   foreach $i (split /\n/,$p_adm->{pay_mess})
   {
      $_=v::filtr($i);
      s/"/`/g; # на апостроф менять нельзя, на альтернативный &#34; тоже - javascript воспринимает как кавычку
      $x=(s/^#(\-?\d+\.?\d*)\s*//)? qq{; document.getElementById("cash").value="$1"; document.getElementById("bonus").checked=true} : '';
      s/\s+$//;
      $i or next;
      $pay_mess.=&RRow('*','l',qq{<span class='data2' style='cursor:pointer;' onClick='javascript: document.getElementById("comment").value="$_"$x'>$_</span>});
   }
   $pay_mess=&Table('table0',$pay_mess).$br if $pay_mess;

   %f=('<b>Текст</b>' => ' ~bold(Текст~)',
       '<span class=borderblue>Текст в рамке</span>' => ' ~frame(Текст~)',
       '<span class=data2>ссылка</span>' => ' ~url(http://~)(Текст~)');

   foreach (keys %f)
   {
      $pay_mess.=qq{<span style='cursor:pointer;' onClick='javascript: document.getElementById("comment").value+=value="$f{$_}"'>$_</span>$br2};
   }

   $user_info.=MessageBox($pay_mess);
   Doc->template('top_block')->{document_ready} .= "\$('cash').focus();\n";
 }
  elsif( Adm->chk_privil('net_pays_create') )
 {
    $out .= v::bold("Вложения и затраты сети").$br2.
       "Приход (уход) в кассу:".$br2.
       "<input type=text name='cash' id='cash' value='$cash' size=14> $gr".$br2.
       v::bold('Комментарий').$br.
       v::input_ta('reason',$F{reason},50,7);
 }
  else
 {
    Error('Выберите клиента перед тем как осуществить платеж.');
 }
 $out.=$br2.v::submit('Провести платеж');
 Show $br.&form('!'=>1,'act'=>'pay', Table('table0', RRow('','t t',$user_info,'',
    WideBox(msg=>$out, css_class=>'h_left')
 )));
}




sub update_category
{# обновление категорий платежей
 Adm->chk_privil('edt_category_pays') or Error('Нет прав на изменение категорий платежей.');
 $i=0;
 $stop=0;
 foreach $f (keys %F)
 {
    next if $f!~/^id_(\d+)/;
    $id=$1;
    $c=int $F{$f};

    $url_id=&ahref("$scrpt&act=show&id=$id",$id);
    $no_chng_mess="<div class='message lft'>Категория платежа с id=$url_id не изменена т.к";
    my %p = Db->line("SELECT * FROM pays WHERE id=$id");
    if( !%p )
    {
        Show "$no_chng_mess не удалось получить информацию об этом платеже, что необходимо для проверки прав на изменение. ".
         "Вероятно, пока вы вносили изменения, другой администратор удалил платеж.</div>";
        $stop++;
        next;
    }

    $p = \%p;
    $old_c=$p->{category};
    next if $old_c==$c;

    if( !Adm->chk_privil('edt_foreign_pays') && Adm->id!=$p->{creator_id} )
    {
        Show "$no_chng_mess у вас нет прав на изменение платежей других администраторов.</div>";
       $stop++;
       next
    }

    if( $p->{type}!=10 )
    {
       Show "$no_chng_mess тип данной записи не допускает ручное изменение категории.</div>";
       $stop++;
       next
    }

    if( $c && !(defined $ct{$c}) )
    {  # это мухлеж
       Show "$no_chng_mess т.к. вы указали несуществующую категорию платежа. Если вы не сжульничали - сообщите администратору о ситуации.</div>";
       $stop++;
       next
    }    

    $rows=Db->do("UPDATE pays SET category=$c WHERE id=$id AND category<>$c LIMIT 1");
    if( $rows==1 )
    {
       $i++; # не делаю $i+=$rows, потому что может вернуть не только нолик или единичку
    }
     else
    {
       Show div('message error',"НЕ удалось обновить категорию платежа с id=$url_id");
       $stop++;
    }
 }

 $url = "$script?".$ses::query."&a=payshow";
 Show div('message cntr',"Категории выбранных платежей обновлены. Всего обновлено <b>$i</b>".$br2.&ahref($url,'Далее &rarr;'));

 return if $stop;
 Doc->template('top_block')->{header}.=qq{<meta http-equiv='refresh' content='10; url="$url"'>};
}

1;
