#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package op;
use strict;
use Debug;

my $d = {
    name        => 'дополнительного поля',
    table       => 'datasetup',
    field_id    => 'id',
    priv_show   => 'Admin',
    priv_edit   => 'SuperAdmin',
    priv_copy   => 'SuperAdmin',
    allow_copy  => 1,
    sql_get     => "SELECT * FROM datasetup WHERE id=?",
    menu_list   => 'Все поля', 
    menu_create => 'Новое поле',
};

# Массив, а не хеш чтобы сохранилась сортировка
my @Fields_flags = (
    'b' => 'убирать пробелы в начале',
    'c' => 'убирать пробелы в конце',
    'd' => 'преобразовать к нижнему регистру',
    'e' => 'транслировать в латинские символы',
    'f' => 'убирать все пробелы',
    'q' => 'титульное поле (выводится в общем списке клиентов)',
    'h' => 'уникальное',
    'i' => 'запретить редактирование',
);
my %Fields_flags = @Fields_flags;

map{ $cfg::Dopfields_tmpl_name{$_} = (split /-/,$cfg::Dopfields_tmpl{$_})[0] } keys %cfg::Dopfields_tmpl;

sub o_start
{
 if( keys %cfg::Dopfields_tmpl_name )
 {
    foreach my $tmpl( sort{$a <=> $b} keys %cfg::Dopfields_tmpl_name )
    {
        push @{$d->{menu}}, [ $cfg::Dopfields_tmpl_name{$tmpl}, tmpl => $tmpl ];
    }
    unshift @{$d->{menu}}, '<br>', 'Разделы:';
 }
 return $d;
}

sub o_list
{
 my $tbl = tbl->new( -class=>'td_wide pretty' );
 my $url = $d->{url}->new();

 my $sql_where = 'WHERE 1';
 my @sql_param = ();

 my $Ftmpl = ses::input('tmpl');
 if( $Ftmpl )
 {
    $sql_where .= ' AND template=?';
    push @sql_param, $Ftmpl;
    $url->{tmpl} = $Ftmpl;
    ToLeft Menu( $url->a("Создать в разделе `$cfg::Dopfields_tmpl_name{$Ftmpl}`", op=>'new', tmpl=>$Ftmpl) );
 }
 
 Doc->template('top_block')->{title} = $Ftmpl ? 
    _('Поля раздела [commas|bold]', $cfg::Dopfields_tmpl_name{$Ftmpl}) : 
    'Все дополнительные поля';

 my $sql = [ "SELECT * FROM datasetup $sql_where ORDER BY template, title", @sql_param ];
 my($sql, $page_buttons, $rows, $db) = main::Show_navigate_list($sql, ses::input_int('start'), 22, $url);

 $rows<1 && Error_(
    "Раздел [filtr|bold] пуст[p h_center]",
    $cfg::Dopfields_tmpl_name{$Ftmpl}, $url->a('Создать', op=>'new', tmpl=>$Ftmpl, -class=>'nav')
 );

 while( my %p = $db->line )
 {
    my $tmpl_name = $cfg::Dopfields_tmpl_name{$p{template}} || [_('[span error]',$p{template})];
    my $title = $p{title};
    my $sort = $title =~ s/^\[(\d+)\]//? $1 : '';
    my $flags = [ join '<br>', grep{ $_ } (
        $p{flags} =~/q/ && 'Титульное',
        $p{flags} =~/h/ && 'Уникальное')
    ];
    $tbl->add('*', 'lrrllllll',
        $tmpl_name,
        $p{id},
        $sort ,
        $title,
        $p{name},
        $lang::dopfield_types{$p{type}},
        $flags,
        $d->btn_edit($p{id}),
        $d->btn_del($p{id}),
    );
 }

 $tbl->ins('head', 'lrrllllC', 'Раздел', 'id', 'Сортировка', 'Название', 'Имя', 'Тип', 'Флаги', 'Операции');

 Show $page_buttons.$tbl->show.$page_buttons;
}

sub o_new
{
 $d->{d}{template} = ses::input_int('tmpl');
}

sub o_edit
{
 $d->{name_full} = _('дополнительного поля [filtr|bold] раздела [filtr|bold]',
    main::Del_Sort_Prefix($d->{d}{title}), $cfg::Dopfields_tmpl_name{$d->{d}{template}}
 );
}

sub o_show
{
 my $types_list = v::select(
    name     => 'type',
    size     => 1,
    selected => $d->{d}{type},
    options  => [ map{ $_ => $lang::dopfield_types{$_} } sort{ $a <=> $b } keys %lang::dopfield_types ],
 );

 my $tmpl_list = v::select(
    name     => 'template',
    size     => 1,
    selected => $d->{d}{template},
    options  => \%cfg::Dopfields_tmpl_name,
 );

 my $checked_flags = join ',', split //, $d->{d}{flags};
 my $flags_list = v::checkbox_list(
    name    => 'flags',
    list    => \@Fields_flags,
    checked => $checked_flags,
 );

 my $title = $d->{d}{title};
 my $sort_order = $title =~ s/^\[(\d+)\]//? int $1 : 0;
 $title = v::input_t( name=>'title', value=>$title );
 $sort_order =  substr "0$sort_order", -2, 2;
 $sort_order = v::input_t(name=>'sort_order', value=>$sort_order);

 my $tbl = tbl->new(-class=>'td_tall td_wide');
 $tbl->add('','ll', 'Раздел',                   [$tmpl_list]);
 $tbl->add('','ll', 'Порядок сортировки',       [$sort_order]);
 $tbl->add('','ll', 'Имя поля',                 [$title]);
 $tbl->add('','ll', 'Имя поля в бд',            [v::input_t(name=>'name', value=>$d->{d}{name})]);
 $tbl->add('','ll', 'Тип поля',                 [$types_list]);
 $tbl->add('','ll', 'Параметры',                [$flags_list]);
 $tbl->add('','ll', 'Регулярное выражение',     [v::input_t(name=>'param', value=>$d->{d}{param})]);
 $tbl->add('','ll', 'Комментарий',              [v::input_ta('comment',$d->{d}{comment},30,5)]);
 $d->chk_priv('priv_edit') && $tbl->add('','C', [ v::submit($lang::btn_save)] );

 Show Center $d->{url}->form( -id=>'dop_form', $tbl->show );
}

my %sql_types = (
  0  => 'BIGINT',       # целое
  1  => 'BIGINT',       # целое положительное
  2  => 'FLOAT',        # вещественное
  3  => 'FLOAT',        # вещественное положительное
  4  => 'VARCHAR(255)', # строковое однострочное
  5  => 'VARCHAR(255)', # строковое многострочное
  6  => 'VARCHAR(1)',   # да/нет
  8  => 'VARCHAR(255)', # выпадающий список
  9  => 'VARCHAR(255)', # пароль
  10 => 'VARCHAR(255)', # трафик
  11 => 'VARCHAR(255)', # время
  13 => 'VARCHAR(255)', # деньги
);

sub makesql
{
 $d->{sql} .= "SET title=?";
 my $Ftitle = v::trim(ses::input('title')) || 'field title';
 my $Fsort_order = substr '0'.ses::input_int('sort_order'), -2, 2;
 push @{$d->{param}}, "[$Fsort_order]$Ftitle";

 my $Fname =  v::trim(ses::input('name'));
 $Fname =~ /^\w+$/ or Error('Не верно задано имя поля в бд. Разрешены только латинские буквы и символ подчеркивания');
 $d->{sql} .= ", name=?";
 push @{$d->{param}}, $Fname;

 $d->{sql} .= ", type=?";
 my $Ftype = ses::input_int('type');
 $Ftype = 0 if ! defined $lang::dopfield_types{$Ftype};
 push @{$d->{param}}, $Ftype;

 $d->{sql} .= ", param=?";
 push @{$d->{param}}, ses::input('param');

 $d->{sql} .= ", template=?";
 my $Ftemplate = ses::input_int('template');
 $Ftemplate = 0 if !defined $cfg::Dopfields_tmpl{$Ftemplate};
 push @{$d->{param}}, $Ftemplate;

 $d->{sql} .= ", flags=?";
 my $Fflags = ses::input('flags');
 $Fflags =~ s/[^a-z]//g;
 push @{$d->{param}}, $Fflags;

 $d->{sql} .= ", comment=?";
 push @{$d->{param}}, ses::input('comment');

 $sql_types{$Ftype} or Error('!');

 return($Fname, $sql_types{$Ftype});
}

sub o_insert
{
 my($name, $sql_type) = makesql();
 my $rows = Db->do("ALTER TABLE `data0` ADD `$name` $sql_type NOT NULL");
 if( !Db->ok )
 {
    Error('Sql error');
 }
 Db->do("ALTER TABLE `data0` ADD INDEX (`$name`)");
}

sub o_update
{
 my($name, $sql_type) = makesql();
 $d->{d}{name} =~ /^\w+$/ or Error('Check table data0 and darasetup!');
 my $rows = Db->do("ALTER TABLE `data0` CHANGE `$d->{d}{name}` `$name` $sql_type NOT NULL");
 if( !Db->ok )
 {
    Error('Sql error');
 }
}

sub o_postdel
{
 Db->do("ALTER TABLE `data0` DROP `$d->{d}{name}`");
}

1;
