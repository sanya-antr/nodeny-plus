#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head

 f_<tbl><alias> : поиск по полю с алиасом <alias> в таблице <tbl> (u:fullusers, d:data0, i:v_ips, s:users_services)
 m_<tbl><alias> : режим поиска в поле name (0-начинается с / 1-фрагмент / 2-совпадение/ ... см $lang::mUsers_search_modes)
    Например, поиск по началу фамилии 'Ивано' и дому = '15'
 f_ufio  = Ивано
 m_ufio  = 0
 f_d_adr_house = 15
 m_d_adr_house = 2

=cut

use strict;
use web::Data;
use services;

sub go{

 my($Url) = @_;
 my $TopLines = [];

 # --- 
 #   Запускается по завершению скрипта, выводит @$TopLines в top документа.
 #   Если ajax, то отсылает команды на отображение блоков сформированного документа
 # ---
 push @{$ses::subs->{exit}}, sub
 {
    my $top_lines = '';
    foreach my $line( @$TopLines )
    {
        ref $line or next;
        my $tbl = tbl->new(-class=>'td_ok');
        $tbl->add('input_short', '^' x scalar @$line, @$line);
        $top_lines .= _('[div top_msg]', $tbl->show);
    }
    Doc->template('base')->{top_lines} = $top_lines.Doc->template('base')->{top_lines};

    $ses::ajax or return;

    foreach my $id( qw{ main_block left_block right_block top_lines } )
    {
        push @$ses::cmd, {
            id   => $id,
            data => Doc->template('base')->{$id},
        };
    }
    push @$ses::cmd, {
        type => 'js',
        data => 'top_search_lock = 0',
    };
 };

 push @$ses::cmd, {
    type => 'js',
    data => "\$('#left_block').hide()",
 };

 # Единицы измерения Мб/Кб/байт, исключая за единицу времени (Мб/сек..): grep{ !$_->[3] }
 push @$ses::cmd, {
    id => 'adm_top_ed',
    data => Set_traf_ed_line('ed', url->new(%$ses::input), [ map{ $_->[4] } grep{ !$_->[3] } @lang::Ed ]),
 };


 # --- Url текущей страницы со всеми фильтрами, кроме номера страницы списка клиентов
 my $UrlF = $Url->new( %$ses::input, start=>undef );

 # --- Url без фильтров, но с выбранными группами
 my $UrlG = $Url->new();

# --------------------------  Группы  --------------------------

 my $Grp_select_block    = '';   # Меню выбора групп
 my $Sql_search_in_grps  = '';   # Через запятую id групп, по которым идет поиск
 my $Selected_grp_urls   = '';   # Через запятую ссылки на группы с выделением выбранных
 my $Selected_grp_names  = '';   # Через запятую имена выбранных групп


 {
    my @selected_grp_urls = ();
    my @selected_grp_names = ();
    my $selected_grp = '';
    my %selected_grp = map{ $_ => 1 } split /,/, ses::input('grps');
    foreach my $grp( Adm->usr_grp_list )
    {
        my $grps;
        if( $selected_grp{$grp} )
        {
            if( $selected_grp )
            {
                $selected_grp .= ',';
            }
            $selected_grp .= $grp;
            $grps = join ',', grep{ $_ != $grp } keys %selected_grp;
        }
         else
        {
            $grps = join ',', keys %selected_grp, $grp;
        }
        my $grp_name = Ugrp->grp($grp)->{name} || $grp;
        my $url = $UrlF->a($grp_name, grps=>$grps, -active=>$selected_grp{$grp});
        $Grp_select_block .= $url;
        push @selected_grp_urls, $url;
        push @selected_grp_names, v::filtr($grp_name) if $selected_grp{$grp};
    }

    if( $selected_grp )
    {
        $UrlG->{grps} = $selected_grp;
        $Sql_search_in_grps = $selected_grp;
    }
     else
    {
        @selected_grp_urls = ();
        $Selected_grp_names = '';
        # Перестраховка int $_ т.к. попадает в sql без фильтрации!! (плейсхолдеры DB модуля не поддерживают конструкцию IN(?) )
        $Sql_search_in_grps = join ',', map{ int $_ } Adm->usr_grp_list;
    }
    $Selected_grp_urls = join ' ', @selected_grp_urls;
    $Selected_grp_names = join ', ', @selected_grp_names;
    $Sql_search_in_grps eq '' && Error('Нет доступа ни к одной группе клиента');
 }


 # -------------------------  Подготовка всех полей  -------------------------

 # $All_fields = { алиас => { данные поля }, ... }
 # Первая буква алиаса - имя таблицы (u/s/i)

 my $All_fields = $Data::All_fields;

 # --------------------  Форма поиска по титульным допданным  --------------------

 my $Title_dopdata_search = '';
 {
    
    foreach my $alias( sort{ $All_fields->{$a}{order} <=> $All_fields->{$b}{order} } keys %$All_fields )
    {
        my $field = $All_fields->{$alias};
        $field->{flag}{q} or next;          # не титульное поле
        $field->{type} == 9 && next;        # пароль
        my $search_field = $field->search( iname => "f_$alias", value => ses::input("f_$alias") );
        # o = 1 (поиск только если строка поиска не пустая)
        # Если поле `выпадающий список`, то поиск по полному совпадению (m=2) иначе `начинается с`
        $Title_dopdata_search .= v::input_h(
            "m_$alias" => ($field->{type} == 8? 2 : 0),
            "o_$alias" => 1,
        );
        $Title_dopdata_search .= _('[filtr]: [] ', $field->{title}, $search_field);
    }

    if( $Title_dopdata_search )
    {
        $Title_dopdata_search = $UrlG->form( -method=>'get', $Title_dopdata_search.v::submit('Поиск') );
    }
 }

 # -----------------------  Глобальный поиск  -----------------------

 if( ses::input('global') ne '' )
 {
    my $Fsearch_str = ses::input('global');   # Строка поиска
    # Режим поиска (начало/фрагмент/...)
    my $Fmode = ses::input_int('mode');

    my $sql = '';
    my @param = ();

    my $order = 0;
    foreach my $alias( sort{ $All_fields->{$a}{order} <=> $All_fields->{$b}{order} } keys %$All_fields )
    {
        my $field = $All_fields->{$alias};
        # разрешен ли глобальный поиск
        $field->{search} > 1 or next;
        # тип поля числовой, а в строке поиска не число?
        $field->{type} =~ /^(0|1|2|3|10|11|13)$/ && $Fsearch_str !~ /^\-?\d+\.?\d*/ && next;
        # к какой таблице относится поле (u/d/i)
        my $t =$field->{tbl};

        my $search = _search_str_by_mode($Fmode, $t.'.'.$field->{name}, $Fsearch_str);
        my $from;
        if( $t eq 'u' )
        {
            $from = "fullusers u WHERE u.grp IN($Sql_search_in_grps) AND $search";
        }
         elsif( $t eq 'd' )
        {
            $from = "data0 d JOIN users u ON d.uid=u.id WHERE u.grp IN($Sql_search_in_grps) AND $search";
        }
         elsif( $t eq 'i' )
        {
            $from = "v_ips i JOIN users u ON i.uid=u.id WHERE u.grp IN($Sql_search_in_grps) AND $search";
        }
         else
        {
            next;
        }
        $sql .= " UNION ALL\n" if $sql;
        $sql .= "SELECT ? AS alias, ? AS title, ? AS `order`, COUNT(*) AS n FROM ".$from." HAVING COUNT(*)>0";
        push @param, $alias, $field->{title}, $order++;
    }

    my $tbl = tbl->new(-class=>'td_ok');
    my $found = 0;
    my $db = Db->sql("SELECT * FROM (\n$sql\n) AS a ORDER BY CAST(a.`order` AS UNSIGNED)", @param);
    while( my %p = $db->line )
    {
        my $alias = $p{alias};

        if( !$found++ )
        {
            $UrlF->{"f_$alias"} = $ses::input->{"f_$alias"} = $Fsearch_str;
            $UrlF->{"m_$alias"} = $ses::input->{"m_$alias"} = $Fmode;
            delete $UrlF->{global};
            delete $UrlF->{mode};
        }

        $tbl->add('', 'lll',
            [ $UrlG->a("Показать $p{n} записей", "f_$alias"=>$Fsearch_str, "m_$alias"=>$Fmode) ],
            $p{title},
            $lang::mUsers_search_tbl->{substr $alias,0,1},
        );
    }

    if( $found )
    {
        push @{$TopLines->[1]}, [ $tbl->show ];
    }
 }

 # -------- Конструирование основного SQL для поиска ---------

 my $Search_info_tbl = tbl->new();   # Таблица по каким полям в данный момент идет поиск
 my @Search_info = ();               # Тоже в ввиде обычного текста

 push @Search_info, "группы: $Selected_grp_names" if $Selected_grp_names;

 my $Sql_select_from = "SELECT u.* FROM fullusers u";
 my $Sql_where = "WHERE u.grp IN($Sql_search_in_grps)";
 my @Sql_param = ();

 my %search_modes_hash = @$lang::mUsers_search_modes;
 my %db_tables_in_search = (); # таблицы, участвующие в поиске

 foreach my $alias( sort{ $All_fields->{$a}{order} <=> $All_fields->{$b}{order} } keys %$All_fields )
 {
    my $field = $All_fields->{$alias};
    $field->{search} or next;

    my $search_str  = ses::input("f_$alias");
    my $search_mode = ses::input("m_$alias");

    # не задана строка поиска
    defined $search_str or next;

    # пустая строка поиска и флаг `искать только если строка поиска не пустая`
    if( ses::input("o_$alias") && $search_str eq '' )
    {   
        delete $UrlF->{"f_$alias"};
        delete $UrlF->{"m_$alias"};
        delete $UrlF->{"o_$alias"};
        next;
    }

    # кнопка отмены поиска по данному полю
    my $cancel_search = [ $UrlF->a($field->{title}, "f_$alias"=>undef, "m_$alias"=>undef, "o_$alias"=>undef) ];

    my $search_mode_select = [ v::select(name => "m_$alias", selected => $search_mode, options => $lang::mUsers_search_modes) ];

    my $search_info;
    my $input_value;
    my $t = substr $alias,0,1; # по какой таблице поиск (u - fullusers, d - data0,..)
    $db_tables_in_search{$t} = 1;

    $Sql_where .= ' AND '._search_str_by_mode($search_mode, $t.'.'.$field->{name}, $search_str);
    # В текстовом виде что ищем, например: ФИО имеет фрагмент `петр`
    push @Search_info, "$field->{title} $search_modes_hash{$search_mode} `".$field->show(value => $search_str)."`";

    $Search_info_tbl->add('', 'llll',
        $cancel_search,
        $search_mode_select,
        [ $field->search( iname => "f_$alias", value => $search_str ) ],
        $lang::mUsers_search_tbl->{$field->{tbl}},
    );

 }

 my($main_fields_block, $dop_fields_block, $srv_fields_block) = ('', '', '');
 foreach my $alias( sort{ $All_fields->{$a}{order} <=> $All_fields->{$b}{order} } keys %$All_fields )
 {
    my $field = $All_fields->{$alias};
    $field->{search} or next;
    my $url = $UrlF->a( $field->{title}, "f_$alias"=>$field->{s_str}.'', "m_$alias"=>$field->{s_mode} );
    my $t = substr $alias,0,1;
    $t eq 's' && next;
    if( $t eq 'u')
    {
        $main_fields_block .= $url;
    }
     else
    {
        $dop_fields_block .= $url;
    }
 }

 {
    # Получим список всех услуг, сгруппированных по модулю, декодирование поля param не производим
    my $services = services->get( decode=>0 );
    $services or last;
    keys %$services or last;
    foreach my $module( keys %$services )
    {
        my $modules = $services->{$module};
        foreach my $service( @$modules )
        {
            $srv_fields_block .= $UrlF->a( $service->{title}, "f_sservice_id"=>$service->{service_id} , "m_sservice_id"=>2 );
        }
        $srv_fields_block .= _('[br]');
    }
 }

 my $filtrs_block =
    $UrlF->a('Авторизованные',              f_iauth => 1,            m_iauth => 2).
    $UrlF->a('Длит. авторизации',           f_itm_auth => 600,       m_itm_auth => 5).
    $UrlF->a('На подключении',              f_ucstate => 1,          m_ucstate => 2).
    $UrlF->a('Доступ заблокирован',         f_ustate => 'off',       m_ustate => 2).
    $UrlF->a('Доступ открыт',               f_ustate => 'on',        m_ustate => 2).
    $UrlF->a('Баланс < 0',                  f_ubalance => 0,         m_ubalance => 5).
    $UrlF->a('Баланс < 0 и доступ открыт',  f_ubalance => 0,         m_ubalance => 5, f_ustate => 'on', m_ustate => 2).
    $UrlF->a('Нулевой исходящий трафик',    f_utraf_out => 0,        m_utraf_out => 2).
    $UrlF->a('Нулевой трафик',              f_utraf => 0,            m_utraf => 2).
    $UrlF->a('Не блокируются по балансу',   f_ublock_if_limit => 0,  m_ublock_if_limit => 2).
    $UrlF->a('Авторизованы авторизатором',  f_iproperties => 'mod=noauth',      m_iproperties => 0).
    $UrlF->a('Авторизованы radius',         f_iproperties => 'mod=radius',      m_iproperties => 0);


 my $tbl = tbl->new();
 $tbl->add('', '^^^^^',
    [ Menu($Url->a('Все записи', all=>1)).Menu($Grp_select_block) ],
    [ Menu($filtrs_block) ],
    [ Menu($main_fields_block) ],
    [ Menu($dop_fields_block) ],
    [ $srv_fields_block && Menu($srv_fields_block) ],
 );
 my $Filters_block = $tbl->show;

 if( !$Search_info_tbl->{rows} && !ses::input('all') && !$Selected_grp_urls )
 {
    # нет ни каких фильтров, и не запрошен вывод всех записей ($F{all})
    unshift @{$TopLines->[0]}, [ $Title_dopdata_search ];
    Show $Filters_block;
    return 1;
 }

 if( ses::input('all') )
 {
    $UrlF->{all} = 1;
    $UrlG->{all} = 1;
 }

 $Selected_grp_urls && $Search_info_tbl->ins('', '4', [$Selected_grp_urls]);

 my $Filtr_descr;
 if( $Search_info_tbl->{rows} )
 {
    $Search_info_tbl->add('', '4', [ v::submit('Обновить') ]);
    $Filtr_descr = _('[div mUsers_search_info]', $Search_info_tbl->show);
 }
  else
 {
    $Filtr_descr = v::submit('Обновить');
 }

 $Filtr_descr = $UrlG->form(-method=>'get', start=>ses::input('start'), $Filtr_descr);

 unshift @{$TopLines->[2]}, [ $UrlF->a('На карту', mod=>'yamap') ];
 unshift @{$TopLines->[2]}, [ $UrlF->a('Трафик', mod=>'traf_log') ];
 unshift @{$TopLines->[2]}, [ $UrlF->a('Платежи', mod=>'pay_log') ];
 unshift @{$TopLines->[1]}, [ url->a('+ фильтр',  -base=>'#show_or_hide', -class=>'nav', -rel=>'filtrs_block') ];
 unshift @{$TopLines->[1]}, [ _('[div h_left input_short]', $Filtr_descr) ];

 Doc->template('base')->{top_lines} .= _('[div filtrs_block hidden]', $Filters_block);


 # --- Сортировка ---

 my $field = $All_fields->{ses::input('sort')};
 if( $field && $field->{type} != 9 )
 {
    my $t = $field->{tbl};
    $db_tables_in_search{$t} = 1;
    my $order_by = $t.'.'.Db->filtr($field->{name});
    if( $field->{type} !~ /^(4|5)$/ )
    {
        $order_by = "CAST($order_by AS SIGNED)";
    }
     elsif( $order_by eq 'i.ip' )
    {
        $order_by = 'i.ipn';
    }

    $UrlF->{sort} = ses::input('sort');
    $UrlF->{sort_dir} = ses::input('sort_dir');
    $Sql_where .= " ORDER BY $order_by";
    $Sql_where .= ' DESC' if !ses::input('sort_dir');
 }else
 {
    $Sql_where .= " ORDER BY u.id DESC";
 }

 $Sql_select_from .= " LEFT JOIN data0 d ON u.id=d.uid" if $db_tables_in_search{d};
 $Sql_select_from .= " LEFT JOIN v_ips i ON u.id=i.uid" if $db_tables_in_search{i};
 $Sql_select_from .= " LEFT JOIN users_services s ON u.id=s.uid" if $db_tables_in_search{s};
 $Sql_select_from .= "\n";

 my $Sql = "$Sql_select_from $Sql_where";

 #--- Ключ, по которому можно перейти на текущий поиск

 my $Return_unikey = Save_webses_data( module=>'users', data=>{ -input=>$ses::input } );


 # --- Выполнение основного sql ---

 if( ses::input('mod') )
 {
    my $ids = [];
    my $db = Db->sql($Sql, @Sql_param);
    while( my %p = $db->line )
    {
        push @$ids, $p{id};
    }
    my $unikey = Save_webses_data(
        module=>ses::input('mod'), data=>{ from=>'users', ids=>$ids, return_to=>$Return_unikey, info=>\@Search_info }
    );
    url->redirect( _unikey=>$unikey );
 }

 my $Sql = [$Sql, @Sql_param];
 my($start, $max_lines) = (ses::input('start'), $cfg::Max_list_users || 20);
 if( ses::input('dump') )
 {   # Запрос дампа инфы по всем клиентам, выбираем всех
    $start = 0;
    $max_lines = 10000;
 }
 my($sql, $page_buttons, $rows, $db) = Show_navigate_list($Sql, $start, $max_lines, $UrlF);

 if( !$rows )
 {
    Show Center _('[p][p]',
        'По фильтру ничего не найдено.',
        ses::input('grps')? 'Попробуйте поиск '.$UrlF->a('во всех группах', grps=>undef) : ''
    );
    return 1;
 }

 Doc->template('top_block')->{add_info} .= "найдено: $rows";

 my $V_ips = {};
 {
    my $db = Db->sql("SELECT * FROM v_ips WHERE uid>0 ORDER BY ip");
    while( my %p = $db->line )
    {
        my $uid = $p{uid};
        $V_ips->{$uid} ||= [];
        push @{$V_ips->{$uid}}, \%p;
    }
 }

 my @Col_header;     # Имена колонок в хедере таблицы
 my @Col_values;     # Значения строки таблицы для текущего клиента
 my $Col_align;
 my $header_made = 0;

 my @Col_all = ();
 my $ShowCols = $ses::cookie->{cols};
 my %Col_show = map{ $_ => 1 } split /,/, $ShowCols;

 my $Need_dump = !!ses::input('dump');
 my %dump = ();

 my($row1,$row2,$rowoff1,$rowoff2) = ('row1','row2','rowoff','rowoff2');

 sub _add_col
 {
    # align : выравнивание (l-left, r-right, c-center)
    # show  : показывать ли колонку, используется в случае, если нет cookie со списком колонок, т.е показ по дефолту
    # alias : alias поля
    # title : заголовок колонки
    # value : значение
    # $header_made устанавливается в 1 после заполнения первой строки таблицы, означает, что сформирован @Col_header заголовка таблицы 
    my($align, $show, $alias, $title, $value) = @_;

    {
        $header_made && last;
        push @Col_all, $alias, $title;
        $Col_show{$alias} = $show if ! $ShowCols;
        # если поиск по колонке - выводим вне зависимости от настроек видимости
        $Col_show{$alias} = 1 if defined ses::input("f_$alias");
        $Col_show{$alias} or last;

        # если поле не виртуальное (существует в бд), то разрешим сортировку по нему
        if( $All_fields->{$alias} )
        {
            my %param = ( sort=>$alias, sort_dir=>!!ses::input('sort_dir') );
            if( ses::input('sort') eq $alias )
            {
                $_ = ses::input('sort_dir')? '&uarr;' : '&darr;';
                $title = [ v::filtr($title).' '.$_ ];
                $param{sort_dir} = !ses::input('sort_dir');
            }
            push @Col_header, [ $UrlF->a($title, %param) ];
        }
         else
        {
            push @Col_header, $title;
        }
    }
    $Col_show{$alias} or return;
    push @Col_values, $value;
    $Col_align .= $align;
 }

 my %already_shown = ();
 my $tbl = tbl->new( -class=>'td_narrow pretty width100 border' );
 while( my %p = $db->line )
 {
    @Col_values = ();
    $Col_align = '';

    my $uid = $p{id};
    $already_shown{$uid}++ && next;
    my $ugrp = $p{grp};

    my $col_auth = '';
    my $col_ips = '';
    my $col_auth_time = '';
    my $col_auth_properties = '';

    if( ref $V_ips->{$uid} )
    {
        foreach my $p( @{$V_ips->{$uid}} )
        {
            $col_ips .= _('[filtr][br]', $p->{ip});
            if( $p->{auth} )
            {
                $col_auth_time .= _('[span nowrap][br]', the_hh_mm($ses::t - $p->{start}));
                $col_auth = $p{state} eq 'on'? 'on.gif' : 'block.gif';
                $col_auth = [ v::tag('img', src=>$cfg::img_url.'/'.$col_auth) ];
                my %prop = map{ split /=/, $_ } split /;/, $p->{properties};
                $col_auth_properties .= _('[span nowrap][br]',$prop{mod});
            }
             else
            {
                $col_auth_time .= _('[br]');
                $col_auth_properties .= _('[br]');
            }
        }
    }

    my $col_info = [ url->a('info', a=>'user', uid=>$uid, -rel=>"?a=ajUserMenu&uid=$uid", -class=>'nav modal_menu') ];

    # --- Дополнительные данные ---
    my $fields = Data->get_fields($uid);
    my @dopdata = ();
    foreach my $alias( sort{ $fields->{$a}{order} <=> $fields->{$b}{order} } keys %$fields )
    {
        my $field = $fields->{$alias};
        $field->{type} == 9 && next; # пароль
        my $def_show = $field->{flag}{q};
        push @dopdata, [ 'l', $def_show, 'd'.$alias, $field->{title}, [$field->show] ];
    }

    # --- Услуги ---
    my @services = ();
    my @next_services = ();
    my $db = Db->sql(
        "SELECT v.*, s.title AS next_title ".
        "FROM v_services v LEFT JOIN services s ON v.next_service_id=s.service_id ".
        "WHERE v.uid=?", $uid
    );
    while( my %p = $db->line )
    {
        push @services, $p{title};
        $p{next_service_id} && push @next_services, $p{next_title}
    }
    my $col_services = join '<br>', map{ v::filtr($_) } @services;
    my $col_next_services = join '<br>', map{ v::filtr($_) } @next_services;

    # --- Трафик по направлениям и суммарный ---
    my %traf = ();
    my $traf_sum = 0;
    foreach( qw{ in1 in2 in3 in4 out1 out2 out3 out4} )
    {
        $traf_sum += $p{$_};
        $traf{$_} = $p{$_};
    }
    my @traf = ();
    foreach my $i( 1..4 )
    {
        push @traf, [ 'r', 0, "utraf$i", "Трафик $cfg::trafname{$i}", [Print_traf($p{"in$i"}+$p{"out$i"}, $ses::cookie->{ed})] ];
    }

    my $balance = $p{balance};
    $balance = _('[span error]',  $balance) if $balance<0;

    my $col_grp = Ugrp->grp($ugrp)->{name};
    my $col_cstate = $lang::cstates{$p{cstate}};
    my $col_traf = [ Print_traf($traf_sum, $ses::cookie->{ed}) ];
    my $col_block_if_limit = $p{block_if_limit}? $p{limit_balance} : '';

    _add_col('c', 1, 'iauth',       'Авт',              $col_auth   );
    _add_col('c', 1, 'uinfo',       'Info',             $col_info   );
    _add_col('l', 0, 'ugrp',        'Группа',           $col_grp    );
    _add_col('r', 0, 'uid',         'Id',               $uid        );
    _add_col('l', 1, 'iip',         'Ip',               [$col_ips]  );
    _add_col('r', 0, 'itm_auth',    'Длит.авт',         [$col_auth_time]        );
    _add_col('l', 0, 'iproperties', 'Мод.авт',          [$col_auth_properties]  );
    _add_col('l', 0, 'ucstate',     'Состояние',        $col_cstate );
    _add_col('l', 0, 'ucontract',   'Договор',          $p{contract});
    _add_col('l', 0, 'uname',       'Логин',            $p{name}    );
    _add_col('l', 1, 'ufio',        'ФИО',              $p{fio}     );
    _add_col(@$_) foreach @dopdata;
    _add_col('l', 1, 'sservice_id', 'Услуги',           [$col_services]);
    _add_col('l', 0, 'snservice_id','След.услуги',      [$col_next_services]);
    _add_col('r', 1, 'utraf',       ['&sum; трафик'],   $col_traf   );
    _add_col(@$_) foreach @traf;
    _add_col('r', 1, 'ubalance',    'Баланс',           [$balance]  );
    _add_col('r', 0, 'ulimit_balance',   'Граница',     $col_block_if_limit);

    if( $Need_dump )
    {
        # ! создание нового массива !
        $dump{$uid} = [@Col_values];
        next;
    }

    my $row = '*';
    $row .= ' disabled' if $p{cstate} == 1;
    $row .= ' row_usr_off' if $p{state} eq 'off';

    $tbl->add($row, $Col_align, @Col_values);
 }
  continue
 {
    $header_made++;
    ($row1,$row2,$rowoff1,$rowoff2) = ($row2,$row1,$rowoff2,$rowoff1);
 }

 if( $Need_dump )
 {
    $dump{header} = \@Col_header;
    #Db->do("INSERT INTO web_dumps SET main_ses=?, data=?", '', Debug->dump(\%dump));
    $Url->redirect(a=>'yamap');
 }

 $tbl->ins('head2 td_tall', 'c' x scalar @Col_header, @Col_header);
 $page_buttons = url->a(['&harr;'], -base=>'#show_or_hide', -class=>'nav', -rel=>'left_block').$page_buttons;
 my $out = $page_buttons.$tbl->show.$page_buttons;
 Show $out;


 my $cols_form = $UrlF->form( -method=>'get',
    _('[][br2][]',
        v::submit('Колонки'),
        v::checkbox_list(
            name    => 'set_cols',
            list    => \@Col_all,
            checked => join(',', grep{ $Col_show{$_} } keys %Col_show),
            buttons => 1,
        )
    )
 );
 ToLeft _('[div txtpadding]', $cols_form);

}

# ---------------------

sub _search_str_by_mode
{
    my($mode, $field, $str) = @_;
    $str =~ s|\\|\\\\|g;
    $str =~ s|(['"%])|\\$1|g;
    $str =~ s|\r|\\r|g;
    $str =~ s|\0|\\0|g;
    return
        $mode==7? "($field IS NULL OR $field = '')" :
        $mode==6? "$field NOT LIKE '$str\%'" :
        $mode==5? "$field<'$str'" :
        $mode==4? "$field>'$str'" :
        $mode==3? "$field!='$str'" :
        $mode==2? "$field='$str'" :
        $mode==1? "$field LIKE '\%$str\%'" :
                  "$field LIKE '$str\%'";
}

1;
