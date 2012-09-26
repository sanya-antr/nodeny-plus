#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008, 2009
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------

$Adm->{id} or Error("Создайте учетную запись для работы с NoDeny. Запись admin только для первоначальной настройки.");
$Adm->{pr}{108} && !$Adm->{pr}{RealSuperAdmin} && Error("Нет прав на изменение личных настроек данной учетной записи. Переключитесь на свою.");

%UsrList_cols=(
 1 => 'Id',
 2 => 'ФИО',
 3 => 'Логин',
 4 => 'Баланс',
 5 => 'Группа',
 6 => 'Контракт',
 7 => 'Дата контракта',
 8 => 'Ip',
 9 => 'Сумма снятия',
10 => 'Телефон',
11 => 'Улица',
12 => 'Дом',
13 => 'Квартира',
14 => 'Баланс с услугами',
15 => 'Граница отключения',
16 => 'Пакет',
17 => 'Трафик направления 1',
18 => 'Трафик направления 2',
19 => 'Трафик направления 3',
20 => 'Трафик направления 4',
21 => 'Трафик суммарный',
22 => 'Следующий пакет',
30 => 'Допполя с флагом `титульные`',
50 => 'яяя_Кнопка `Пополнить счет`',
51 => 'яяя_Кнопка `Статистика`',
52 => 'яяя_Кнопка `Карта`',
53 => 'яяя_Кнопка `Все на точке`',
54 => 'яяя_Кнопка `Все на доме`',
);

$return=$br2.$Url->a('Посмотреть настройки', a=>'mytune');

{
   $F{act} eq 'save_pass' or last;

   if( $Adm->{pass} ne $F{old_man} )
   {
        ErrorMess('Текущий пароль указан неверно.'.$br2.'Пароль не изменен.');
        last;
   }
   if( $F{new_man1} ne $F{new_man2} )
   {
        ErrorMess("Новый пароль не совпадает с его повторным вводом. Пароль не изменен.");
        last;
   }
   if( length($F{new_man1})<6 || $F{new_man1} =~ /^\s+/ || $Fpasswd1 =~ /\s+$/ )
   {
        ErrorMess("Пароль не может быть меньше 6 символов, а также начинаться или заканчиваться пробелом.".$br2."Пароль не изменен.");
        last;
   }

   my $rows = Db->do(
        "UPDATE admin SET passwd=AES_ENCRYPT(?,?) WHERE id=? LIMIT 1",
        [$F{new_man1},$cfg::Passwd_Key,$Adm->{id}]
   );
   # Удалим все активные сессии данного админа
   $rows>0 && remove_session( -made => 'Ваш пароль для доступа в административный интерфейс успешно изменен.');

   ErrorMess("Пароль не изменен. Попробуйте снова или обратитесь к главному администратору.");
}

if ($F{act} eq 'save')
{
   $email=$F{email};
   if ($email=~/^[a-zA-Z_\.-][a-zA-Z0-9_\.-\d]*\@[a-zA-Z\.-\d]+\.[a-zA-Z]{2,4}$/)
   {
      $set_email=",email='$email'";
   }
    elsif ($email=~/^\s*$/)
   {
      $set_email=",email=''";
   }
    else
   {
        ErrorMess("Email задан неверно, поэтому не изменен");
        $set_email='';
   }  

   # сообщения от клиентов в каких группах будут отсылаться на email админа. Если в будущем доступы будут изменены -
   # это не скажется на безопасности т.к перед отправкой сообщений будут дополнительные проверки
   $email_grp='';
    foreach $g (sort {$UGrp_name{$a} cmp $UGrp_name{$b}} keys %UGrp_name)
    {
        $Adm->{grp_lvl}{$g} or next;
        $email_grp.="$g," if $F{"g$g"};
    }
   $email_grp=~s|,$||;
   $email_grp=",email_grp='$email_grp'";

   $tunes='1,1';
   $tunes.=',showsql,1' if $F{showsql};
   $tunes.=',ShowIpInPays,1' if $F{ShowIpInPays};

   foreach $g (keys %UsrList_cols)
   {
      map{ $tunes.=",cols-$_-$g,1" } grep{ $F{"cols-$_-$g"} } (0..1)
   }

   $rows=Db->do("UPDATE admin SET pay_mess='".&Filtr_mysql($F{pay_mess})."',tunes='$tunes' $set_email $email_grp WHERE id=$Adm->{id} LIMIT 1");
   Show MessageBox('Данные обновлены'.$return);
   Exit();
}

if ($F{act} eq 'save_pic')
{
   $pic=$cgi->param('pic');
   if ($pic)
   {
      $pic!~/\.(jpg|jpeg|gif|png|tif|tiff)$/i && &Error("Картинка должна иметь одно из следующих расширений: jpg, jpeg, gif, png, tif, tiff");
      $ext=lc($1);
      $ffile.="$Adm_img_f_dir/Adm_$Adm->{id}.$ext";
      $FileOut='';
      while (read($pic,$b,1024)) {$FileOut.=$b}
      open(FL,">$ffile") or &Error("Ошибка загрузки аватара <b>$ffile</b>. Возможно папка не существует либо недоступна на запись. Обратитесь к главному администратору");
      binmode(FL);
      print FL $FileOut;
      close(FL);
      Show MessageBox("<img src='$Adm_img_dir/Adm_$Adm->{id}.$ext'>".$br3.v::bold("Аватар загружен").$return);
   }
    else
   {
      $ext='';
      Show MessageBox( v::bold('Аватар удален') );
   } 
   $rows = Db->do("UPDATE admin SET ext='$ext' WHERE id=$Adm->{id} LIMIT 1");
   &Exit;
}

# === Отображение параметров ===

$row_id=5;

Show "<div class=message>".$br.&div('big','Ваши настройки').$br.
  "<table><tr><$tc valign=top>".
    &form('!'=>1,'act'=>'save_str',&Table('width100 tbg1',$out)).
  "</td><$tc valign=top>";

# ИСПРАВИТЬ
$Admin_pay_mess = $p_adm->{pay_mess};

# ИСПРАВИТЬ
# сообщения от клиентов в каких группах будут отсылаться на email админа
$Aemail_grp=','.$p_adm->{email_grp}.',';
$email_grp='';
foreach $g( sort{ $UGrp_name{$a} cmp $UGrp_name{$b} } grep{ $Adm->{grp_lvl}{$_} } keys %UGrp_name )
{
   $email_grp.="<input type=checkbox value=1 name=g$g".($Aemail_grp=~/,$g,/ && ' checked')."> $UGrp_name{$g}".$br;
}

$usrlist_cols='';
foreach $g (sort {$UsrList_cols{$a} cmp $UsrList_cols{$b}} keys %UsrList_cols)
{
   @usrlist_cols=@usrlist_header=();
   foreach (0..1)
   {
       push @usrlist_header,'&nbsp;&nbsp;Вид '.($_+1).'&nbsp;&nbsp;';
       push @usrlist_cols,"<input type='checkbox' value=1 name='cols-$_-$g'".(defined($Adm->{tunes}{"cols-$_-$g"}) && ' checked').'>';
   }
   $h=$UsrList_cols{$g};
   $h=~s|^яяя_||;
   $usrlist_cols.=&RRow('*','l'.('c' x 2),$h,@usrlist_cols);
}

$usrlist_cols=&Table('tbg',
   &RRow('* head','c' x 3,'Название поля',@usrlist_header).
   $usrlist_cols
);

$out=&form('!'=>1,'act'=>'save',
  &div('story','Перечислите сообщения, которые вы чаще всего посылаете клиентам. Они будут выводится рядом с полем ввода сообщения, '.
    'при этом, кликнув по одному из них, выбранная фраза занесется в поле ввода.'.$br2.
    'Если в начале сообщение стоит #число, то поле ввода наличных также будет установлено в это число (можно указывать с минусом).').$br.
  v::input_ta('pay_mess',$Admin_pay_mess,56,12).$br2.
  "Оформление:".$br2.
  &Table('tbg3',
  # ИСПРАВИТЬ
    &RRow('*','ll','Ваш email',v::input_t(name=>'email',value=>$p_adm->{email})).
    &RRow('*','ll','Выводить ip клиента в списке платежей',"<input type=checkbox value=1 name=ShowIpInPays".(!!$Adm->{tunes}{ShowIpInPays} && ' checked').'>').
    ($Adm->{pr}{SuperAdmin} && &RRow('*','ll','Режим вывода отладочных сообщений',"<input type=checkbox value=1 name='showsql'".(!!$Adm->{tunes}{showsql} && ' checked').'>'))
  ).$br2.
  MessageBox("Выберите группы, сообщения от клиентов которых, вы будете получать на email:".$br2.$email_grp).$br.
  &div('story',"Отметьте галочками те колонки, которые вы хотите видеть в выводе списка клиентов. Предусмотрено несколько видов отображений, ".
     "в работе вы можете переключаться между ними, скажем для первого вида предусмотреть только самые необходимые поля, а для второго - все.").$br.
     $usrlist_cols
  .$br.
  v::submit('Сохранить').$br
);

Show div('message lft',$out);

# данные при передаче картинки передаем методом get т.к. не переварит скрипт adm, сама картинка передается post-ом
Show $br3.MessageBox("Вы можете загрузить аватар (эмблему), которая будет выводиться в левом верхнем углу админки.".$br.
    "Если не выбрать никакой файл, то аватар будет удален и будет использован аватар по умолчанию (эмблема сети)".$br2.
    "<form method=post action='$script' enctype='multipart/form-data'>".v::input_h('act','save_pic').
    "<input type=file name=pic size=50 value=''>$br2<input type='submit' value='Загрузить'></form>",1);

Show $br3.MessageBox("Если желаете изменить пароль для вашей учетной записи,".$br2.
   &form('!'=>1,'act'=>'save_pass',
     &Center(
       &Table('tbg1',
         &RRow('*','rl','введите текущий пароль','<input type=password name=old_man size=30>').
         &RRow('*','rl','новый пароль','<input type=password name=new_man1 size=30>').
         &RRow('*','rl','новый пароль','<input type=password name=new_man2 size=30>').
         &RRow('*','C',v::submit('Изменить'))
       )
     )
   ),1
);

Show '</td></tr></table></div>';

1;

