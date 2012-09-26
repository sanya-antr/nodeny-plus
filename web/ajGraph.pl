#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head

 Ajax модуль построения графиков. Входные параметры:

 domid   : dom id, куда необходимо послать код графика
 group   : показывать графики только с данным именем группы
 y_title : подпись графика по оси y (`Трафик Мб/с`)
 type    : тип графика, 1  - по дням, 0 - по часам за одни сутки

 Данные графиков предварительно должны быть записаны в таблицу
 webses_data в поле data в виде perl-дампа :
 {
    group  => группа графика
    points => [ [x1,y1], [x2,y2], ..],
    descr  => описание графика
 }

 Например, подготавливаем данные:

 Save_webses_data(
    module=>'ajGraph', data=>{
        points => [ [1,100], [2,200] ],
        descr  => 'Трафик клиента xxx',
        group  => 'traf_xxx',
    }
 );

 Выводим:

 Doc->template('base')->{document_ready} .= <<AJAX;
    nody.ajax({
        a       : 'ajGraph',
        domid   : 'main_block',
        group   : 'traf_xxx',
        y_title : 'МБайт'
    });
AJAX

=cut
use strict;

sub go
{
 push @$ses::cmd, {
    id   => ses::input('domid'),
    data => _proc(),
 };

 push @$ses::cmd, {
    type => 'js',
    data => 'nody.graph()',
 };

 return 1;
}

sub _proc
{
 my $cur_module = ses::cur_module;
 # Имя группы
 my $group = ses::input('group');
 # Степень `грубости` графика
 my $graph_rough = ses::input_int('graph_rough');
 # Сколько срезов группировать в один
 my $graph_rough_lvl = 2 ** $graph_rough;

 my $series = [];
 my $db = Db->sql(
    "SELECT * FROM webses_data WHERE role=? AND aid=? AND module=? ORDER BY created",
    $ses::auth->{role}, $ses::auth->{uid}, $cur_module
 );
 while( my %p = $db->line )
 {
    my $VAR1;
    my $data = eval $p{data};
    if( $@ )
    {
        debug('error', "Ошибка парсинга данных по ключу `$p{unikey}`: $@");
        next;
    }
    ref $data eq 'HASH' or next;
    $group eq $data->{group} or next;

    # Если срезы группируются в один, то вычисляется сумма площадей за период и делится на величину периода

    my $points = '';
    my $sum = 0;
    my $i = 0;
    my $last_x;
    my $start_x = $last_x = scalar @{$data->{points}}? scalar $data->{points}[0][0] : 0;
    while( my $point = shift @{$data->{points}} )
    {
        my($x, $y) = @$point;
        $sum += $y * ($x-$last_x);
        $last_x = $x;
        scalar @{$data->{points}} && ++$i < $graph_rough_lvl && next;
        if( $i>1 )
        {
            # среднее значение по оси x
            $x = int(($last_x+$start_x)/2);
            $y = sprintf '%.3f', $sum / ($last_x-$start_x);
        }
        $points .= "[$x,$y]\n,";
        $i = 0;
        $sum = 0;
        $start_x = $last_x;
    }
    chop $points;

    # экранируем кавычки в имени графика, поскольку оно идет в JS темплейт
    my $name = $data->{descr};
    $name =~ s/'/\\'/g;
    push @$series, { points=>$points, name=>$name, id=>$p{unikey} };
 }

 my $slider = _('[div graph_slider]', 
    join('', map{
        url->a('', 
            -ajax=>1, -class=>($_==$graph_rough && 'active'),
            graph_rough=>$_, a=>$cur_module, group=>$group,
            y_title=>ses::input('y_title'), domid=>ses::input('domid'), type=>ses::input('type')
        )
    }( 0..7 ))
 );

 my $msg = "<div id='graph_buttons'>$slider </div>";

 return tmpl('graph',
    series  => $series,
    msg     => MessageWideBox($msg),
    group   => $group,
    domid   => ses::input('domid'),
    y_title => ses::input('y_title'),
    type    => ses::input_int('type'),
 );
}

1;
