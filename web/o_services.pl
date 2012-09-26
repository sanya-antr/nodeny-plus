#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package op;
use strict;
use Debug;
use web::Data;

my $d = {
    name        => 'услуги',
    table       => 'services',
    field_id    => 'service_id',
    priv_show   => 'Admin',
    priv_edit   => 'SuperAdmin',
    priv_copy   => 'SuperAdmin',
    allow_copy  => 1,
    sql_get     => 'SELECT s.*, '.
                    '(SELECT COUNT(*) FROM users_services WHERE service_id=s.service_id) AS now_count, '.
                    '(SELECT COUNT(*) FROM users_services WHERE next_service_id=s.service_id) AS next_count '.
                    'FROM services s WHERE s.service_id=?',
    menu_list   => 'Все услуги', 
    #menu_create  не указываем т.к услуга создается с заданием модуля
};

$cfg::dir_services = "$cfg::dir_home/services";

opendir(DIR, $cfg::dir_services) or 
    Error_(
        'Не могу прочитать каталог с услугами: [filtr|p]'.
        'Если существует - проверьте права доступа.',
        $cfg::dir_services
    );
my %Modules = map{ $_ => $_ } grep{ s/^(.+)\.pm$/$1/ } readdir(DIR);
closedir(DIR);
keys %Modules or Error_('Нет ни одного модуля услуг (файла *.pm) в каталоге: [filtr|p]', $cfg::dir_services);

foreach my $module( keys %Modules )
{
    push @{$d->{menu}}, [ "Создать услугу `$module`", op=>'new', module=>$module ];
}

sub _load_service
{
 my($module) = @_;
 $module or Error('Не задана услуга');
 exists $Modules{$module} or Error_("Файл [filtr|bold] не существует", "$cfg::dir_services/$module.pm");
 my $pkg = "services::$module";
 eval "use $pkg";
 my $fields = $pkg->tunes;
 foreach my $field( @$fields )
 {
    bless $field, 'Data';
 }
 return($pkg, $fields);
}

sub o_start
{
 return $d;
}

sub o_list
{
 Doc->template('top_block')->{title} = 'Услуги';
 my $tbl = $d->{tbl};
 my $url = $d->{url}->new();

 my $sql = 'SELECT s.*,COUNT(u.uid) AS users FROM services s LEFT JOIN users_services u '.
                'ON s.service_id = u.service_id '.
                'GROUP BY s.service_id ORDER BY s.module';
 my @sql_param = ();
 my($sql, $page_buttons, $rows, $db) = main::Show_navigate_list([$sql, @sql_param], ses::input('start'), 24, $url);

 if( $rows < 1)
 {
    Error( scalar @sql_param? 'Фильтру не соответствует ни одина услуга' : 'В базе данных пока нет ни одной услуги' );
 }

 while( my %p = $db->line )
 {
    my $usr = $p{uid}? [ url->a($p{uid}, -ajax=>1, a=>'ajUserInfo', uid=>$p{uid}) ] : '';
    $tbl->add('*', [
        [ '',           'Модуль',           $p{module}      ],
        [ '',           'Название',         $p{title}       ],
        [ 'h_right',    'Цена',             $p{price}       ],
        [ 'h_center',   'Автопродление',    $p{auto_renew}? $lang::yes : '' ],
        [ 'h_center',   'У клиентов',       $p{users}       ],
        [ 'h_center',   '',                 $d->btn_edit($p{service_id})    ],
        [ 'h_center',   '',                 $d->btn_del($p{service_id})    ],
    ]);
 }

 Show $page_buttons.$tbl->show.$page_buttons;
}

sub o_new
{
 $d->{d}{module} = ses::input('module');
 $d->{d}{param} = {};
}

sub o_edit
{
 my $VAR1;
 eval $d->{d}{param};
 if( $@ )
 {
    debug('error', "$@");
    ToTop 'Внимание. Параметры услуги не расшифрованы, т.к. они повреждены';
    $d->{d}{param} = {};
 }
  else
 {
    $d->{d}{param} = $VAR1;
 }
 $d->{name_full} = _('услуги [filtr|bold] модуля [filtr|commas]', $d->{d}{title}, $d->{d}{module});
 # Запрет на удаления
 $d->{no_delete} = "услуга подключена к $d->{d}{now_count} клиентам" if $d->{d}{now_count}>0;
 $d->{no_delete} = "услуга установлена как `следующая` у $d->{d}{next_count} клиентов" if $d->{d}{next_count}>0;
}

sub o_show
{
 my $module = $d->{d}{module};
 my($pkg, $fields) = _load_service($module);

 Doc->template('top_block')->{title} = _('[] услуги', $d->{name_action});

 my $tbl = tbl->new(-class=>'td_tall td_wide');

 $tbl->add('*', 'lll',
    'Модуль услуги',
    $module,
    $pkg->can('description') && [ $pkg->description ],
 );
 $tbl->add('*', 'lll',
    'Имя услуги',
    [ v::input_t( name=>'title', value=>$d->{d}{title} ) ],
    '',
 );
 $tbl->add('*', 'lll',
    'Стоимость',
    [ v::input_t( name=>'price', value=>$d->{d}{price} ) ],
    $cfg::gr,
 );
 $tbl->add('*', 'lL',
    'Описание, которое будут видеть клиенты. Можно html',
    [ v::input_ta('description', $d->{d}{description}, 60, 6) ],
 );

 $tbl->add('*', 'lll',
    'Автопродление',
    [ v::checkbox( name=>'auto_renew', value=>1, checked=>$d->{d}{auto_renew}, label=>'да') ],
    'При подключении данной услуги, она автоматически будет назначена следующей по завершению текущей.',
 );

 $tbl->add('*', 'lll',
    'Запрет продления',
    [ v::checkbox( name=>'no_renew', value=>1, checked=>$d->{d}{no_renew}, label=>'да') ],
    'Запретить клиентам продлевать эту услугу',
 );
 my @grp_list = map{ $_ => Ugrp->grp($_)->{name} } keys %{Ugrp->hash};
 my $grp_list = v::checkbox_list(
    name    => 'grp_list',
    list    => \@grp_list,
    checked => $d->{d}{grp_list},
    buttons => 1,
 );

 $tbl->add('*', 'lll',
    '',
    [ $grp_list ],
    'Группы, клиенты которых могут самостоятельно устанавливать услугу. К администраторам это не относится',,
 );

 foreach my $field( @$fields )
 {
    my $alias = $field->{name};
    my %param = ( iname=>$alias );
    $param{value} = $d->{d}{param}{$alias} if defined $d->{d}{param}{$alias};
    $tbl->add('', 'lll',
        $field->{title},
        [ $field->form( %param ) ],
        [ $field->{comment} ],
    );
 }

 $d->chk_priv('priv_edit') && $tbl->add('','3', [ v::submit($lang::btn_save) ]);

 Show Center $d->{url}->form( module=>$module, $tbl->show );
}

sub o_update
{
 my $module = ses::input('module');
 my($pkg, $fields) = _load_service($module);
 my $param = {};
 foreach my $field( @$fields )
 {
    my $alias = $field->{name};
    $field->{new_value} = ses::input($alias);
    my($err_msg, $save_value) = $field->check();
    if( $err_msg )
    {
        Error_('[] (параметр [filtr|commas])', $err_msg, $field->{title});
    }
    $param->{$alias} = $save_value;
 }
 $d->{sql} .= "SET module =?, title = ?, description = ?, price = ?, auto_renew = ?, no_renew =?, grp_list = ?";
 push @{$d->{param}}, $module;
 push @{$d->{param}}, v::trim(ses::input('title')) || 'service title';
 push @{$d->{param}}, ses::input('description');
 push @{$d->{param}}, ses::input('price') + 0;
 push @{$d->{param}}, ses::input_int('auto_renew');
 push @{$d->{param}}, ses::input_int('no_renew');
 # по краям `,` для простых регекспов в sql
 push @{$d->{param}}, ','.(join ',', grep{ Ugrp->grp($_) } split /,/, ses::input('grp_list')).',';

 $d->{sql} .= ", param = ?";
 push @{$d->{param}}, Debug->dump($param);
}

sub o_insert
{
    return o_update(@_);
}

1;
