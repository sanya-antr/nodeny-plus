#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

sub Get_filtr_fields
{
 my @f = @_;
 return map{ v::filtr($p->{$_}) } (@f);
}

sub Get_fields
{
 return map{$p->{$_} }(@_);
}

sub CenterA
{
 return Center( div('nav',ahref(@_)) );
}

$Adm->{pr}{SuperAdmin} or Error('Недостаточно привилегий.');
$Adm->{trusted} or Error('Не разрешен доступ, поскольку при авторизации вы не указали, что работаете за доверенным компьютером.');

ToTop _('[]&nbsp;[]&nbsp;[]',
    $Url->a('Список администраторов', act=>'list_admin', -class=>'nav'),
    $Url->a('Добавить нового', act=>'new_admin', -class=>'nav'),
    $Url->a('Главные настройки', a=>'tune', -class=>'nav')
);

my %subs = (
 'new_admin'    => 1,
 'save_new'     => 1,
 'list_admin'   => 1,
 'del_admin'    => 1,
 'del_admin_now'=> 1,
 'edit_priv'    => 1,
 'update_priv'  => 1,
 'edit_data'    => 1,
 'update_data'  => 1,
 'copy_data'    => 1,
 'copy_data_now'=> 1,
);

my $Fact = $F{act};
$Fact='list_admin' if ! $subs{$Fact};

&{$Fact};

Exit();

sub get_admin_data
{
 $id = int $F{id};
 $p = sql_select_line($dbh,"SELECT *,AES_DECRYPT(passwd,'$Passwd_Key') FROM admin WHERE id=$id LIMIT 1","SELECT *,AES_DECRYPT(passwd,'...') FROM admin WHERE id=$id LIMIT 1");
 if( !$p )
 {
    $p=&sql_select_line($dbh,"SELECT time FROM changes WHERE tbl='admin' AND act=2 AND fid=$id");
    $p && Error( the_short_time($p->{time},1)." учетная запись администратора № $id была удалена." );
    Error("Не существует учетная записи администратора с id=$id.");
 }
 ($login,$privil) = Get_fields('login','privil');
}

sub SPriv
{
 ($r1,$r2)=($r2,$r1) if $_[0];
 $_=$_[1];
 $row_id++;
 my $url = url->a(['[&darr;]'], -base=>'#show_or_hide', -rel=>"my_x_$row_id");
 $out.="<tr class=$r1>".($_[3]? "<$tc>".$url : '<td>&nbsp;');
 $out.="</td><td><input type=checkbox name=a$_ value=1 onchange=\"javascript:document.form.a$_.className='modified';\"".($pr{$_}? ' checked' : '')."></td><$tl colspan='2'>$_[2]</td></tr>";
 $out.="<tr class='$r1 my_x_$row_id' style='display:none'><$tl colspan='4'>$_[3]</td></tr>" if $_[3];
}

sub check_admin_login
{
 my $Flogin = trim($_[0]);
 $Flogin =~ /[^a-zA-z0-9]/ && Error("В логине администратора использованы недопустимые символы. Разрешаются только латинские буквы и цифры.");
 $Flogin or Error("Поле `логин` не должно быть пустым или равным 0.");
 return $Flogin;
}

sub show_admin_url
{
 my($id, $msg) = @_;
 ToTop _('[]&nbsp;([]&nbsp;&nbsp;[])',
    $msg,
    $Url->a('Привилегии', act=>'edit_priv', id=>$id),
    $Url->a('Данные', act=>'edit_data', id=>$id),
 );
}

# -----------------------------------
sub new_admin
{
 Doc->template('base')->{main_v_align} = 'middle';
 ToTop 'Создание учетной записи нового администратора';
 Show MessageBox(
    $Url->form( act => 'save_new',
        Table('tbg1',
            RRow('','ll', $lang::msg_login, v::input_t(name=>'login')).
            RRow('','ll', $lang::msg_pass,  v::input_t(name=>'passwd'))
        ).
        Center( v::submit($lang::btn_go_next) )
    )
 );
}


sub save_new
{
 my $Flogin = check_admin_login($F{login});
 my $Fpasswd = trim($F{passwd});
 my %p = Db->select_line("SELECT login FROM admin WHERE login=? LIMIT 1", $Flogin);
 # даже если кто-то параллельно успеет вставить запись с таким логином, то INSERT не выполнится из-за уникальности поля
 %p && Error_('[] [bold] [][p]', 'Админ с логином', $Flogin, 'уже существует.','Учетная запись администратора не создана.');
 Db->do("INSERT INTO admin SET login=?, passwd=AES_ENCRYPT(?,?)", $Flogin, $Fpasswd, $cfg::Passwd_Key);
 my $id = Db::result->insertid;
 $id or Error_('[p][p]',"Ошибка при выполнении sql-запроса создания учетной записи $Flogin.","Возможно администратор с таким логином уже существует.");
 ToLog("!! $Adm->{info_line} Создан новый администратор с логином $Flogin.");
 $Url->redirect( act => 'edit_priv', id => $id, -made => "Создана учетная запись администратора с логином $Flogin")
}

sub del_admin
{
 get_admin_data();
 ErrorMess(
    $Url->form( act => 'del_admin_now', id =>$id,
        _('[] [bold][p][p]',
            'Вы собираетесь удалить запись администратора с логином', $login,
            "Перед удалением рекомендуется осуществить передачу наличных другому администратору (раздел 'Платежи')",
            Center(v::submit('УДАЛИТЬ'))
        )
    )
 );
}

sub del_admin_now
{
 get_admin_data();
 my $rows = Db->do("DELETE FROM admin WHERE id=? LIMIT 1", $id);
 $rows<1 && Error("Учетная запись администратора с логином `$login` НЕ удалена.");
 ToLog("!! $Adm->{info_line} Удалена учетная запись администратора $login (id=$id)");
 Db->do("INSERT INTO changes SET tbl='admin',act=2,fid=$id,adm=$Adm->{id},time=unix_timestamp()");
 $Url->redirect( act => '', -made => "Учетная запись администратора с логином `$login` удалена");
}

sub list_admin
{
 $colspan=9;
 $header=&RRow('tablebg','c3ccccc','Логин','Редактировать','[X]','Имя','Должность','Разрешен','Суперадмин?');
 $out='';
 $outleft='';
 $sth=&sql($dbh,"SELECT * FROM admin ORDER BY login");
 while( $p=$sth->fetchrow_hashref )
 {
    ($login,$privil,$id) = Get_fields('login','privil','id');
    %pr = ();
    $pr{$_} = 1 foreach( split /,/,$privil );
    $enabled = $pr{1}? '' : 'отключен';
    $super = $pr{3}? '<span class=error>Суперадмин</span>' : $pr{2}? 'Повышенные привилегии' : '&nbsp;';
    ($name,$post)=&Get_filtr_fields('name','post');
    $out .= RRow($pr{1}? '*': 'rowoff','llllllccc',
        v::bold($login),
        ahref("$scrpt&act=edit_priv&id=$id",'Привилегии'),
        ahref("$scrpt&act=edit_data&id=$id",'Данные'),
        ahref("$scrpt&act=copy_data&id=$id",'Копия'),
        ahref("$scrpt&act=del_admin&id=$id",'Х'),
        "<div nowrap>$name</div>",
        $post,
        $enabled,
        $super
    );
 }
 $out or Error_('[p h_center][p h_center]',
    'Не создана ни одна учетная запись администратора.',
    $Url->a('Создать', act=>'new_admin')
 );
 Show Table('width100 nav2',
   &RRow('','tt',
     $outleft && MessageBox($outleft),
     &Table('tbg3',&RRow('head',$colspan,v::bold('Список администраторов')).$out)
   )
 );
}

sub edit_priv
{
 &get_admin_data;
 $row_id=0;
 $pr{$_}=1 foreach (split /,/,$privil);
 $nbsp="&nbsp;" x 4;
 show_admin_url($id, _('[] [bold]', 'Редактирование привилегий администратора ', $login));
 $out=
   &RRow('nav','4',qq{<a href='#' onclick="SetAllCheckbox('privs',1); return false;">Отметить все</a> <a href='#' onclick="SetAllCheckbox('privs',0); return false;">Убрать все</a>},'&nbsp;').
   "<tr class=row1><td width=3%>&nbsp;</td><td width=3%><input type=checkbox name=a1 value=1 onchange=\"javascript:document.form.a1.className='modified';\"".
       ($pr{1} && ' checked')."></td><td colspan=2>Включен</td></tr>";
 $out.=&RRow('head','4', v::bold('Привилегии суперадмина'));

 SPriv(1,3,'Суперадмин');
 
 $out.=&RRow('head','4', v::bold('Важные привилегии'));
 SPriv(1,2, 'Просмотр ключевых настроек NoDeny');
 SPriv(1,15,'Удаление учетных записей клиентов','Не рекомендованная операция т.к. возможно создание временных записей для временной работы, затем их удаление. Лучше создать специальную группу &#171;удаленные&#187;');
 SPriv(1,17,'Просмотр финансового отчета','Просмотр финансового отчета. Предоставляется только для тех групп клиентов и отделов, к которым админ имеет доступ');

 $out.=&RRow('head','4',v::bold('Карточки пополнения счета. Важные привилегии.'));
 SPriv(1,21,'Доступ к административной странице карточек пополнения счета');
 SPriv(1,22,'Генерация/удаление карточек');
 SPriv(1,23,'Просмотр кодов пополнения');

 $out.=&RRow('head','4',v::bold('Карточки пополнения счета.'));
 SPriv(1,116,'Может принимать карточки от других администраторов','Другими словами, иные администраторы могут оформлять передачи карточек на текущего администратора');
 SPriv(1,111,"Перевод личных карточек в состояние ".v::commas('можно активировать без продажи'),'В обычном случае, карточку возможно активировать только после того как она была продана. В момент продажи, когда в биллинге указывается, что такая-то карта продана, ставится признак, что ее можно активировать. Это хорошо с точки зрения безопасности. Однако, если текущий админ - реализатор, который продает карточки НЕ через NoDeny, то необходимо дать возможность пометить свои карточки как разрешенные к активации');

 $out.=&RRow('head','4',v::bold('Работники'));
 SPriv(1,24,"Редактирование данных работников");
 SPriv(1,25,"Назначение заданий работникам");
 SPriv(1,29,"Регистрация начала/окончания трудового дня работника");
  
 $out.=&RRow('head','4',v::bold('Платежи. Важные привилегии'));
 SPriv(1,11,'Редактирование платежей любого времени создания','Чтобы избежать махинаций в виде редактирования платежей предыдущих дней (месяцев), дайте это право только доверенному админу, а обычным админам лишь право на редактирование в течение 10 минут после создания');
 SPriv(1,12,'Редактирование чужих платежей','Разрешение редактирования платежей другого администратора. Желательно давать право только суперадминистратору');
 SPriv(1,13,'Запретить редактирование своих платежей другими администраторами','Редактирование платежей данного админа будет блокироваться для других админов даже если у них есть право на редактирование чужих платежей');
 SPriv(1,27,'Изменение категорий платежей','Данное право дает возможность администратору относить существующие платежи к категориям для последующего анализа в отчете категорий поступлений и затрат');
 SPriv(1,19,'Оформление передач наличных между администраторами');
 
 $out.=&RRow('head','4',v::bold('Просмотр платежей'));
 SPriv(1,51,'Просмотр платежей');
 SPriv(1,52,"Просмотр платежей другого администратора",'Отсутствие данного права НЕ БЛОКИРУЕТ ПОЛНОСТЬЮ возможность узнать платежи другого администратора. Это связано с тем, что при просмотре платежей клиента администратор должен видеть &#171;полную картину&#187; - все платежи этого клиента. Отсутствие данного права блокирует:<br> - просмотр платежей проведенных другим администратором как &#171;затраты сети&#187;<br> - вывод списка платежей другого администратора с просмотром наличности &#171;на руках&#187;');
 SPriv(1,14,'Просмотр событий');

 $out.=&RRow('head','4',v::bold('Проведение платежей'));
 SPriv(1,54,"Пополнение счета клиента");
 SPriv(1,56,"Оформление временных платежей",'Платежи, которые автоматически удалятся через заданное количество дней.');
 SPriv(1,57,"Проведение платежей `задним` числом",'Для проведения `забытых` платежей. Право давать только доверенным админам.');
 SPriv(1,53,"Проведение `неактуальных платежей`",'Неактуальные платежи - платежи, которые существовали до внедрения NoDeny в другой биллинговой системе. Эти платежи можно проводить `задним` числом до определенной даты, указываемой в настройках. В обычном случае `неактуальные платежи` не нужны.');
 SPriv(1,58,"Проведение платежей как затраты сети",'Расходы и поступления не связанные напрямую с клиентами.');
 SPriv(1,59,"Оформление зарплат/авансов работникам");
 SPriv(1,55,"Отправка сообщения клиенту");
 SPriv(1,34,"Отправка многоадресных сообщений (всей сети или определенным группам)");
 SPriv(1,60,"Редактирование/удаление платежей не старее 10 минут от их создания",'Это право позволяет изменить/удалить ошибочный платеж если он был создан в течение последних 10 минут. Это дает возможность исправить ошибку, с другой стороны не дает жульничать путем изменения более ранних платежей.');
 SPriv(1,62,"Админ может участвовать в передачах наличности между администраторами, т.е может быть получателем либо отправителем средств");
  
 $out.=&RRow('head','4',v::bold('Привилегии'));
 SPriv(1,61,"Просмотр пароля клиента");
 SPriv(1,70,"Изменение данных клиента");

 $out.=&RRow($r1,'4',"$nbsp Какие поля разрешается менять:");
 &SPriv(0,72,"$nbsp Логин");
 &SPriv(0,71,"$nbsp Пароль");
 &SPriv(0,73,"$nbsp Группу");
 &SPriv(0,74,"$nbsp Контракт");
 &SPriv(0,75,"$nbsp ФИО");
 &SPriv(0,77,"$nbsp Доступ в интернет");
 &SPriv(0,78,"$nbsp Границу отключения");
 &SPriv(0,69,"$nbsp % скидки");
 &SPriv(0,79,"$nbsp Состояние (вирусы/ремонт/настроить)");
 &SPriv(0,80,"$nbsp Авторизация (авторизатором или нет)");
 &SPriv(0,82,"$nbsp Дополнительные данные");
 &SPriv(0,86,"$nbsp Комментарий");

 $out.=&RRow($r1,'4','');
 SPriv(1,100,"Доступ к клиентской статистике");

 SPriv(1,88,'Создание учетных записей клиентов');
 SPriv(1,106,'Мониторинг системы');

 $out.=&RRow('head','4',v::bold('Топология сети'));
 SPriv(1,94,'Доступ к разделу топологии сети');
 SPriv(1,95,'Изменения в разделе топологии сети');

 $out.=&RRow('head','4',v::bold('Контакты'));
 SPriv(1,98,'Доступ к контактам: управление личными контактами, просмотр контактов своего отдела');
 SPriv(1,104,'Просмотр контактов чужих отделов');
 SPriv(1,99,'Изменение контактов своего отдела');
 SPriv(1,105,'Изменение контактов других отделов');

 $out="<table width=90% class=tbg1 id=privs>$out</table>".$br;

 $out.="<table width=90% class=tbg1>".
   &RRow('head','4',v::bold('Ограничения прав')).
   "<tr class=row1><td width=3%>&nbsp;</td><td width=3%>&nbsp;</td><td colspan=2>&nbsp;</td></tr>";
 &SPriv(1,108,"Запрет на изменение личных настроек",'Запрет на загрузку аватора, изменение личного пароля и т.д. Ставить галку для общей для нескольких админов учетной записи');
 &SPriv(1,120,"При создании учетной записи клиента не показывать окно выбора логина, а устанавливать его (логин) автоматически по транслитерации ФИО");
 &SPriv(1,300,'Прием карточек пополнения счета без подтверждения','Ставить галку только в том случае, если текущая запись является записью реализатора, который не имеет доступа к админке NoDeny, т.е. не может подтвердить прием карточек');
 &SPriv(1,301,'Автоматический перевод принятых карточек в режим '.v::commas('можно активировать'),'Ставить галку только в том случае, если текущая запись является записью реализатора, который продает карточки не через админку NoDeny');
 $out.='</table>'.$br;

 Show MessageBox(
    $Url->form( act => 'update_priv', id =>$id, Center(v::submit('Сохранить')).$out )
 );
}

sub update_priv
{
 &get_admin_data;
 $Fprivil='0';
 map { $Fprivil.=",$1" if /^a(\d+)$/ } keys %F;

 $privil.=',';
  my @f = (
  1, 'учетная запись',
  3, 'суперадмин',
  5, 'ред. учеток админов',
  10,'ред. тарифов',
  11,'ред. платежей любого времени создания',
  15,'удаление клиентов',
  17,'просмотр финотчета',
  18,'ред. без установки признака редактирования',
  22,'генерация/удаление карточек пополнения',
  28,'ред. событий',
  30,'переключение на любого админа своего отдела',
  31,'переключение на любого админа',
  33,'просмотр кодов карточек пополнения',
  61,'просмотр паролей клиентов',
 );
 my $warn = '!';
 my $msg = '';
 while( my $i = shift @f )
 {
    $_ = $F{"a$i"};
    my $m = shift @f;
    $msg .= ", $m - $_" if ($_ && $privil!~/,$i,/ && ($_='вкл') && ($warn='!!')) ||
                          (!$_ && $privil=~/,$i,/ && ($_='выкл'));
 }

 my $rows = Db->do("UPDATE admin SET privil=? WHERE id=? LIMIT 1", $Fprivil, $id);
 $rows<1 && Error("Произошла ошибка при выполнении sql-запроса. Привилегии администратора $login не изменены.");
 ToLog("$warn $Admin_UU Изменены привилегии администратора $login (id=$id)$msg (priv: $Fprivil)");
 $Url->redirect( act => 'edit_priv', id => $id, -made => "Изменены привилегии администратора $login");
}

sub edit_data
{
 &get_admin_data;
 ($passwd,$name,$post)=&Get_filtr_fields("AES_DECRYPT(passwd,'$Passwd_Key')",'name','post');
 &show_data($id,$id);
} 


sub copy_data
{
 get_admin_data();
 ErrorMess(
    'Вы собираетесь создать копию учетной записи администратора '.v::bold($login).'.'.$br2.
        'Будут скопированы все права и доступы к группам.'.$br2.
        CenterA("$scrpt&act=copy_data_now&id=$id",'Создать копию').&ahref($scrpt,'Не создавать')
 );
}


sub copy_data_now
{
 get_admin_data();
 $privil= Db->filtr($privil);
 $old_login = $login;
 $login="COPY_$id";
 $sth=$dbh->prepare("INSERT INTO admin (login,passwd,name,privil) VALUES ('$login',AES_ENCRYPT('-','$Passwd_Key'),'-','$privil')");
 $sth->execute;
 $new_id=$sth->{mysql_insertid} || $sth->{insertid}; # значение id только что внесенной записи
 &Error("Ошибка при выполнении sql-запроса создания учетной записи.") unless $new_id;
 &ToLog("!! $Admin_UU Создана копия учетной записи администратора $old_login. Имя новой учетной записи $login.");
 ($passwd,$name,$post)=('-','-',&Get_filtr_fields('post'));
 &show_data($id,$new_id);
}

sub show_data
{
 ($id,$save_id)=@_;
 ToTop 'Редактирование данных администратора';

 $row_id=0;

 # к каким группам разрешен доступ
 $list_grp='';
 $sth = sql($dbh,"SELECT * FROM user_grp ORDER BY grp_name");
 while( $p=$sth->fetchrow_hashref )
 {
    $grp_id=$p->{grp_id};
    # в начале и в конце всегда стоят нули, а дальнейшие проверки включают щаблон /,группа,/, т.е все админы попадут в шаблон
    $list_grp.="<input type=checkbox value=1 name=g$grp_id".($p->{grp_admins}=~/,$id,/ && ' checked').
     "><input type=checkbox value=1 name=gg$grp_id".($p->{grp_admins2}=~/,$id,/ && ' checked').
     '> '.&Filtr_out($p->{grp_name}).$br;
 } 

 $out=
    RRow('*','ll','Логин',v::input_t(name=>'login', value=>$login)).
    RRow('*','ll','Пароль',v::input_t(name=>'passwd', value=>$passwd)).
    RRow('*','ll','Имя',v::input_t(name=>'name', value=>$name)).
    RRow('*','ll','Должность',v::input_t(name=>'post', value=>$post));

 if( $list_grp )
 {
    $list_grp=qq{<div id=allgrp>$list_grp</div><a href='#' onclick="SetAllCheckbox('allgrp',1); return false;">Отметить все</a>$br<a href='#' onclick="SetAllCheckbox('allgrp',0); return false;">Убрать все</a>};
    $out.=&RRow('*','lll','Доступ к группам клиентов',$list_grp,
       '1 галочка - ограниченный доступ к группе (только просмотр ip, логина, ФИО, адреса)'.$br2.
       '2 галочки - полный доступ к группе.'.$br2.
       'Отсутствие галочек - полное сокрытие группы');
 }

 Show MessageBox(
    $Url->form( act => 'update_data', id => $save_id,
        Table('tbg3',$out).
        Center( v::submit('Сохранить') )
    )
 );
}

sub update_data
{
 &get_admin_data;
 $oldpasswd=$p->{"AES_DECRYPT(passwd,'$Passwd_Key')"};

 my $Flogin = check_admin_login($F{login});

 $p=&sql_select_line($dbh,"SELECT * FROM admin WHERE login='$Flogin' AND id<>$id");
 $p && &Error('Запись с логином '.v::bold($Flogin).' уже существует!');

 $Fpasswd=trim(Db->filtr($F{passwd}));
 $Fname=Db->filtr($F{name});

 $Fpost=Db->filtr($F{post});

 $rows=$dbh->do("UPDATE admin SET login='$Flogin',passwd=AES_ENCRYPT('$Fpasswd','$Passwd_Key'),name='$Fname',post='$Fpost' WHERE id=$id LIMIT 1");
 $rows<1 && &Error("Произошла ошибка при выполнении sql-запроса. Данные администратора не изменены.");
 ToLog("! $Admin_UU Изменены данные администратора $login.".
   ($login ne $Flogin && " Новый логин $Flogin.").
   ($oldpasswd ne $F{passwd} && ' Изменен пароль.')
 );

 # к каким группам разрешить доступ
 $sth=&sql($dbh,"SELECT * FROM user_grp");
 while ($p=$sth->fetchrow_hashref)
 {
    $grp_id=$p->{grp_id};
    $g1=$p->{grp_admins};
    $g2=$p->{grp_admins2};
    $g1=~s|,$id,|,|;
    $g2=~s|,$id,|,|;
    $g1=~s|0$||;
    $g2=~s|0$||;
    $g1.="$id," if $F{"g$grp_id"} || $F{"gg$grp_id"};
    $g2.="$id," if $F{"g$grp_id"} && $F{"gg$grp_id"};
    $g1.='0';
    $g2.='0';
    Db->do("UPDATE user_grp SET grp_admins='$g1',grp_admins2='$g2' WHERE grp_id=$grp_id LIMIT 1");
 }

 # Если пароль менялся - удалим все активные сессии данного админа
 if( $oldpasswd ne $F{passwd} )
 {
    Db->do("DELETE FROM admin_session WHERE admin_id=?", $id);
 } 

 $Url->redirect( act => 'edit_data', id => $id, -made => "Изменены данные администратора $Flogin");
}

1;
