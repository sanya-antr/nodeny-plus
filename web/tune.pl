#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use vars qw( %F );

$cfg::dir_config = "$cfg::dir_home/cfg";

my $config = "package cfg;\n";

my $edt_priv = Adm->chk_privil('SuperAdmin');
$edt_priv or Adm->chk_privil_or_die('Admin');
$edt_priv = '' if !$ses::auth->{adm}{trust};

my $url = url->new( a=>ses::cur_module );

my @cfg_lines = ();

opendir(DIR, $cfg::dir_config) or 
    Error_('Не могу прочитать каталог [filtr|bold|p]Если существует, проверьте права доступа', $cfg::dir_config);
my @configs = grep{ /.cfg$/ } readdir(DIR);
closedir(DIR);

# Если у плагина свой конфиг - добавим к основному
foreach my $file( @configs )
{
    $file = "$cfg::dir_config/$file";
    open(F,"<$file") or Error_($lang::cannot_load_file,$file);
    push @cfg_lines, $_ while( <F> );
    close(F);
}

sub _ToTop
{
 Doc->template('base')->{top_lines} .= v::div( class=>'top_msg txtpadding h_left', -body=>join('',@_) );
}

sub filtr_param
{
 local $_=shift;
 s|\\|\\\\|g;
 s|'|\\'|g;
 s|\r||g;
 return $_;
}

my $cfg_line = 0;
sub next_line
{
    while( scalar @cfg_lines > $cfg_line)
    {
        $_ = $cfg_lines[$cfg_line++];
        /^\s*#/ && next; # комментарий
        /^\s*$/ && next; # пустая строка
        /\s*(.)\s+(.+?)\s+(.+?)\s+'(.*)'\s*$/ && return($1,$2,$3,$4);
        debug('error', "Ошибочная строка:\n$_");
    }
    return undef;
}

my $Fact = $F{act};

if( $Fact eq 'save' || $Fact eq 'normal' )
{
 $edt_priv or Error($lang::err_no_priv);
 my $need_restart = 0;
 while( 1 )
 {
    my($type,$name,$params,$comment) = next_line();
    defined $type or last;

    $type eq 'R' && next;

    if( $type =~ /[sfnb]/ )
    {  # параметр - переменная
        no strict;
        my $old = ${"cfg::$name"};
        use strict;
        my $new = $old;
        if( defined $F{$name} )
        {
            $new = $F{$name};
            $new =~ s|\s+$||; # уберем завершающие пробелы в переданных через форму данных
            $new = $old if $params =~ /=/ && $new eq ''; # скрытый параметр и ничего не введено - не меняем
            if( $new ne $old )
            {
                ToTop _('[span data2]: [][br][filtr|commas] &rarr; [filtr|commas]','Изменен параметр',$comment,$old,$new);
                $need_restart = 1 if $params =~ /r/;
            }
        }
        if( $type eq 'f' && $new && !(-e $new) )
        {
            ToTop _('[][br][span error]: [filtr|commas]',$comment,'Файл не существует',$new);
        }
        if( $type eq 's' || $type eq 'f' )
        {  # строковой параметр
            $new =~ s|\n| |g;
            $new ="'".filtr_param($new)."'";
        }
         elsif( $type eq 'n' )
        {  # число
            $new =~ /^-?\d*\.?\d*$/ or ToTop _('[][br][span error]: [filtr|commas]',$comment,'Параметр должен быть числом',$new);
            $new += 0;
        }
         else
        {   # $type eq 'n' and others
            $new = int $new;
        }

        $config .= "\$$name = $new;\n";
        next;
    }

    if( $type eq '@' )
    {  # параметр - массив.
        no strict;
        my @old = @{"cfg::$name"};
        use strict;
        my @new;
        if( defined $F{$name} )
        {  # отфильтровываем символ 'возврат каретки' (\r)
            $F{$name} =~ s/\n+|(\r\n)+/\n/g;
            @new = split /\n/,$F{$name};
            if( "@new" ne "@old" )
            {
                ToTop _('[span data2]: []','Изменен параметр',$comment);
                $need_restart = 1 if $params =~ /r/;
            }
        }
         else
        {
            @new = @old;
        }

        $config .= "\@$name = (\n '".join("',\n '",map{ filtr_param($_) } @new)."'\n);\n";
        next;
    }

    if( $type eq 'm' || $type eq 'g' )
    {  # хеш или трехэлементный хеш (элемент1 => "элемент2-элемент3")
        my %new = ();
        no strict;
        my %old = %{"cfg::$name"};
        use strict;
        if( defined($F{"$name#a1"}) )
        {
            foreach my $i( 1 .. 100 )
            {
                my $a = $F{"$name#a$i"};
                $a =~ s|\s+$||;
                if( $type eq 'g' )
                {
                    my $b = $F{"$name#b$i"};
                    $a =~ s|-| |; # '-' является разделителем
                    $b =~ s|-| |;
                    $b =~ s|\s+$||;
                    $a .= '-'.$b if $b ne '';
                }
                $a eq '' && next;
                $new{$i} = $a;
            }
            if( join('',map{ $_.'|'.$new{$_}} sort keys %new)
                 ne
                join('',map{ $_.'|'.$old{$_}} sort keys %old)
              )
            {
                ToTop _('[span data2]: []','Изменен параметр',$comment);
                $need_restart = 1 if $params =~ /r/;
            }
        }
         else
        {
            %new = %old;
        }
        $config .= "\%$name = (\n";
        while( my($key,$val) = each %new )
        {
           $val = filtr_param($val);
           $key = filtr_param($key);
           $config .= " '$key' => '$val',\n";
        }
        $config .= ");\n";
        next;
    }
 }

 

 # запишем конфиг в БД
 my $rows = Db->do("INSERT INTO config SET time=unix_timestamp(),data=?", $config);
 $rows<1 && ToTop _('[span error]','Ошибка записи конфига в базу данных');
 if( $F{Passwd_Key} && $F{Passwd_Key} ne $cfg::Passwd_Key )
 {  # изменился ключ кодированияь
    Db->do("UPDATE users SET passwd=AES_ENCRYPT(AES_DECRYPT(passwd,?),?)", $cfg::Passwd_Key, $F{Passwd_Key});
    Db->do("UPDATE admin SET passwd=AES_ENCRYPT(AES_DECRYPT(passwd,?),?)", $cfg::Passwd_Key, $F{Passwd_Key});
 }

 package cfg;
 no strict;
 eval $config;
 use strict;
 package main;

 debug('pre',$config);
 ToTop _('[div big]','Конфигурационный файл записан успешно.');
}

# =======       Отображение параметров      ===========

my @menu = ();
my $Fi = int $F{i}+1;   # выбранный раздел
my $section = 0;        # счетчик разделов
my $tbl = tbl->new( -class => 'tune_tbl_narrow tune_tbl' );
$cfg_line = 0;
while( 1 )
{
  my($type,$name,$params,$comment) = next_line();
  defined $type or last;

  if( $type eq 'R' )
  {  # раздел меню
    $_ = $url->new(i=>$section);
    $_->{-class} = 'navmenu_active' if ($section+1)==$Fi;
    push @menu, $_->a($comment);
    ++$section == $Fi or next;
    ToTop _($lang::section_is,$comment);
    $name ne '-' && $tbl->set( -class => $name.' tune_tbl' );
    next;
  }

  $section == $Fi or next;

  $comment =~ s|\\n|<br>|g;

  if( $type eq 'm' || $type eq 'g' || $type eq 'C' )
  {
    # массив или трехэлементный массив
    $tbl->add('','E',[$comment]);
    $type eq 'C' && next;
    # количество элементов хеша возъмем = текущее (приведенное к четному) + 8
    no strict;
    my $count = int((keys %{"cfg::$name"})/2 * 2) + 8;
    use strict;
    # вложенная таблица с 6 колонками (3 колонки на элемент хеша)
    my $tbl2 = tbl->new();
    my @cell = ();
    foreach my $i( 1 .. $count )
    {
        no strict;
        my $val1 = ${"cfg::$name"}{$i};
        use strict;
        my $val2 = '';
        if( $type eq 'g' )
        {
            $val2 = $val1 =~ s/^([^\-]+)-(.*)$/$1/? $2 : '';
            $val2 = v::input_t( name=>"$name#b$i", value=>$val2 );
        }
        push @cell, [ _("№[bold]", $i) ], [ v::input_t( name=>"$name#a$i", value=>$val1 ) ], [ $val2 ];
        scalar @cell < 6 && next;
        $tbl2->add('*', 'llllll', @cell);
        @cell = ();
    }
    $tbl->add('*', '3', [$tbl2->show]);
    next;
  }

  if( $type eq '@' )
  {
     no strict;
     my @val = @{"cfg::$name"};
     use strict;
     $tbl->add('*','E',[$comment.'<br>'.v::input_ta($name, join("\n",@val), 255, scalar(@val)+3)]);
     next;
  }

  no strict;
  my $val = ${"cfg::$name"};
  use strict;

  if( $type =~ /[sfn]/ )
  {  # параметр - переменная
     $val = '' if $params =~ /=/;
     if( $params =~/4/ )
     {
         $tbl->add('','E',[$comment.'<br>'.v::input_ta($name, $val, 255, 4)]);
         next;
     }
     $val = v::input_t( name=>$name, value=>$val );
  }
   elsif( $type eq 'b' )
  {  # да/нет
     $val = "<select name='$name' size='1'>".
         ($val? "<option value=1 selected>Да<option value=0>Нет</option>" : "<option value=1>Да<option value=0 selected>Нет</option>").
        '</select>';
  }else
  {
    debug('error','Неизвестный код параметра '.$type.'. имя: '.$comment);
  }
  $tbl->add('', 'Ll', [$val], [$comment]); 
}

my $body;
if( $edt_priv )
{
    $tbl->ins('', '3', [ v::submit('Сохранить') ]);
    $body = $tbl->show;
    $body = $url->form('act'=>'save', 'i'=>$Fi-1, $body);
}
 else
{
    $body = $tbl->show;
}


foreach (
    'Ip пул|ip_pool',
    'Сети|nets',
    'Группы клиентов|usr_grp',
    'Словари|dictionary',
    'Услуги|services',
    'Доп. поля|datasetup',
    'Точки топологии|places',
)
{
    my($title,$act) = split /\|/, $_, 2;
    push @menu, $url->a($title, a=>'op', act=>$act);
}


push @menu, url->a('Администраторы', a=>'admin');

my $menu = Menu(join '', @menu);

ToLeft $menu;
Doc->template('base')->{css_left_block} = 'mTune_left_block';

Show $body;

1;
