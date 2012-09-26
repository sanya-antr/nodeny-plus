#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head
  График трафика
    tm_stat     : timestamp любой секунды дня, на который строится график
    traf_cls    : направление трафика (1..4), 0 - сумма по всем направлениям
    uid         : id клиента
    ids         : список id клиентов (передается не через браузер, а БД)
=cut

use strict;
use Time::Local;

sub go
{
 my($url) = @_;

 # Если определен $ses::unikey, то значит некоторые данные переданы не через http, а через БД по этому ключу
 $url->{_unikey} = $ses::unikey if defined $ses::unikey;

 # Информация о последнем срезе
 {
    my %p = Db->line("SELECT DATE_FORMAT(NOW(), 'X%Y_%c_%e') AS t");
    %p or last;
    %p = Db->line("SELECT (UNIX_TIMESTAMP()-MAX(time)) AS time FROM ".$p{t});
    %p or last;
    Doc->template('top_block')->{add_info} = $p{time}<0? 
        _('[span warn]', 'Есть записи из будущего') :
        _('Последний срез [bold] сек назад', $p{time});
 }

 my $descr = ''; # словесное описание текущего фильтра

 my $sql_where = '';
 my @sql_where = ();

 my $Ftraf_cls = ses::input_int('traf_cls');
 if( $Ftraf_cls )
 {
    $url->{traf_cls} = $Ftraf_cls;
    $sql_where .= ' AND class=?';
    push @sql_where, $Ftraf_cls;
    $descr = "Трафик `$cfg::trafname{$Ftraf_cls}`";
 }
  else
 {
    $descr = 'Трафик всех направлений';
 }

 my $Ftm_stat = ses::input_int('tm_stat') || $ses::t;
 $url->{tm_stat} = $Ftm_stat if ses::input_exists('tm_stat');
 $descr .= ' '.the_date($Ftm_stat);

 # Получим имена таблиц за текущий и прошлый дни
 my @tbls = ();
 foreach my $day( 0..1 )
 {
    my %p = Db->line("SELECT DATE_FORMAT(FROM_UNIXTIME(?) - INTERVAL ? DAY, 'X%Y_%c_%e') AS t", $Ftm_stat, $day);
    %p or Error($lang::err_try_again);
    push @tbls, $p{t};
 }

 my $traf_tbl_name = $tbls[0];

 # Последняя отметка времени в срезе предыдущего дня нужна чтобы знать длительность первого среза
 my $first_time = 0;
 if( Db->line("SHOW tables LIKE '$tbls[1]'") )
 {   # таблица может и не существовать
    my %p = Db->line("SELECT MAX(time) AS t FROM $tbls[1]");
    $first_time = $p{t} if %p;
 }

 my @sql;

 # Передан список клиентов или id клиента? int т.к. попадает в sql !!!
 my $uid = ref $ses::data && ref $ses::data->{ids}? join ',', map{ int $_ } @{$ses::data->{ids}} : ses::input_int('uid');

 if( $uid )
 {
    if( $uid =~ /^\d+$/ )
    {
        $url->{uid} = $uid;
        my $info = Get_usr_info($uid);
        $info->{full_info} ||= "Для клиента id=$uid";
        !Adm->chk_usr_grp($info->{grp}) && !Adm->chk_privil('SuperAdmin')
            && Error("Нет доступа к группе user id=$uid");
        ToRight MessageWideBox( $info->{full_info} );
        $descr .= " клиента $info->{name}";
    }
     else
    {
        ToRight WideBox(
            msg   => join('<br>',@{$ses::data->{info}}),
            title => 'Клиенты по фильтру',
        );
        $descr .= '<br>клиентов: '.join('<br>',@{$ses::data->{info}});
    }


    # Когда клиент ничего не качал, необходимо принять трафик = 0 в этот срез, поэтому такой корявый sql
    @sql = (<<SQL
    SELECT time, SUM(`in`) AS traf_in, SUM(`out`) AS traf_out FROM (
        SELECT time, `in`, `out` FROM $traf_tbl_name WHERE 1 $sql_where AND uid IN($uid)
            UNION
        SELECT time, 0, 0 FROM $traf_tbl_name WHERE uid = 0
    ) AS trf GROUP BY time ORDER BY time
SQL
        , @sql_where
    );

 }
  else
 {
    @sql = (
        "SELECT time, SUM(`in`) AS traf_in, SUM(`out`) AS traf_out FROM $traf_tbl_name ".
        "WHERE 1 $sql_where GROUP BY time ORDER BY time", @sql_where
    );
 }

 # --- Меню выбора типа трафика и даты --
 {
    my $menu = '';

    $menu .= $url->a( 'Все направления', traf_cls=>undef, -active=>!$Ftraf_cls );
    foreach my $traf_cls( 1..4 )
    {
        $menu .= $url->a( $cfg::trafname{$traf_cls}, traf_cls=>$traf_cls, -active=>($traf_cls==$Ftraf_cls) );
    }
    $menu .= '<hr>';
    $menu .= $url->post_a( "На график", graph=>1 );
    
    $menu .= ses::input('show') eq 'graph'?
            $url->a( "Скрыть графики",   show=>undef ) :
            $url->a( "Показать графики", show=>'graph' );

    ToRight Menu( $menu );

    ToRight MessageWideBox( Get_list_of_stat_days(substr($traf_tbl_name,0,1), $url, $Ftm_stat) );

    # Выбор единиц измерения
    Doc->template('top_block')->{urls_ed} = Set_traf_ed_line('ed_log', $url, [ map{ $_->[4] } @lang::Ed ] );
 }

 my $make_graph = ses::input_int('graph');

 if( ses::input('show') eq 'graph' && !$make_graph )
 {
    Doc->template('base')->{document_ready} .= 
        "\n nody.ajax({ a:'ajGraph', domid:'main_block', group:'_traf_', y_title:'Трафик, мбит/с' });";
    return 1;
 }

 my $db = Db->sql( @sql );

 my $traf_rows = $db->rows;
 my $max_traf_per_sec = 1;
 my $sum_traf_in  = 0;
 my $sum_traf_out = 0;
 my $last_time = $first_time;
 my @lines = ();
 my $cur_in = 0;
 my $cur_out = 0;

 while( my %p = $db->line )
 {
    $cur_in = $p{traf_in};
    $cur_out = $p{traf_out};
    my $period = $p{time} - $last_time;
    # В знаменателе не может быть 0 т.к. GROUP BY time, но перестрахуемся
    my $traf_per_sec = $cur_in / ($period || 1);
    $max_traf_per_sec = $traf_per_sec if $traf_per_sec > $max_traf_per_sec;
    $sum_traf_in  += $cur_in;
    $sum_traf_out += $cur_out;
    unshift @lines, { time=>$p{time}, traf_in=>$cur_in, traf_out=>$cur_out, period=>$period, traf_per_sec=>$traf_per_sec };
    $last_time = $p{time};
    $cur_in = $cur_out = 0;
 }

 # Создадим гиперссылку для перехода на ранмоду traf. Поскольку вызовов url->a будет много,
 # оптимизируем путем однократного преобразования неизменных параметров в -base
 my $url2 = url->new( -base=>$url->url( a=>'traf', traf_cls=>$Ftraf_cls, _unikey=>undef ) );
 my $traf_ed = $ses::cookie->{ed_log};
 my $tbl = tbl->new( -class=>'td_wide' );
 my $points = [];

 while( my $p = shift @lines )
 {
    my $percent = sprintf "%.2f", $p->{traf_per_sec} * 100 / $max_traf_per_sec;
    $percent = 100 if $percent>100;
    my $time = $p->{time};
    if( $make_graph )
    {
        # все графики условно будут от 1 января 1970:
        # - разные дни будут накладываться друг на друга как один
        # - короткий timestamp
        my $gmtime = timegm(@{localtime($time)}[0..2],1,0,1970);
        unshift @$points, [ $gmtime, sprintf "%.3f", $p->{traf_in}/$p->{period}/125000 ];
        next;
    }
    my $link     = [ $url2->a('срез', tm_stat=>$time) ];
    my $the_hour = [ the_hour($time) ];
    my $traf_in  = $p->{traf_in}?  [ Print_traf($p->{traf_in},  $traf_ed, $p->{period}) ] : '';
    my $traf_out = $p->{traf_out}? [ Print_traf($p->{traf_out}, $traf_ed, $p->{period}) ] : '';
    my $graph    = [ _('[div mTraf_log_graph]', v::div(style=>"width:${percent}%")) ];
    $tbl->add('* nowrap', [
        [ '',           '',                 $link       ],
        [ 'h_center',   'Время',            $the_hour   ],
        [ 'h_right',    'Входящий',         $traf_in    ],
        [ 'h_right',    'Исходящий',        $traf_in    ],
        [ '',           'График скорости',  $graph      ],
    ]);
 }

 if( $traf_rows<1 )
 {
    Show Center _('[br][br][big]', 'Нет данных по текущему фильтру');
 }
  elsif( $make_graph )
 {
    my $unikey = Save_webses_data(
        module=>'ajGraph', data=>{ points=>$points, descr=>$descr, group=>'_traf_' }
    );
    $url->redirect( show=>'graph' );
 }
  else
 {
    Show Center $tbl->show;

    # Общая статистика за весь период во всех единицах измерения
    my $period = $last_time-$first_time;
    my $tbl = tbl->new(-class=>'td_ok');
    $tbl->add('head', 'rrl', 'in', 'out', '');
    foreach my $ed(
        [' B00', 'Byte'],
        ['Kb11', 'Kbit/s'],
        ['Mb11', 'Mbit/s'],
    ){
        $tbl->add( '', 'rrl',
            [ Print_traf($sum_traf_in,  $ed->[0], $period,1) ],
            [ Print_traf($sum_traf_out, $ed->[0], $period) ],
            $ed->[1],
        );
    }
    ToLeft WideBox( msg=>$tbl->show, title=>'Итого за период' );
 }
 
}

1;