#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use web::Pay;

sub go
{
 my($url) = @_;

 Adm->chk_privil_or_die('report');

 # Статистика с накоплением?
 my $need_sum = ses::input_int('sum');
 my $need_graph = ses::input('days')? ses::input_int('graph') : 1;

 my $days = ses::input_int('days') || 31;
 $days = 31 if $days < 0 or $days > 750;

 my $category = ses::input_int('category');
 my $categories = { 0 => ' '.'Положительные платежи' };

 my $db = Db->sql('SELECT DISTINCT category FROM pays WHERE cash<>0');
 while( my %p = $db->line )
 {
    $categories->{$p{category}} = Pay::category($p{category});
 }

 ToTop $url->form( make=>1,
    _('[] [] день [] [] []',
        v::select(
            name     => 'category',
            size     => 1,
            selected => $category,
            options  => $categories,
        ),
        v::input_t(name=>'days', value=>$days, size=>4),
        v::checkbox(
            name    => 'sum',
            value   => 1,
            label   => 'накопление',
            checked => $need_sum,
        ),
        v::checkbox(
            name    => 'graph',
            value   => 1,
            label   => 'график',
            checked => $need_graph,
        ),
        v::submit('Показать'),
    )
 );

 if( !ses::input('make') )
 {
    # Если не заказано формирование статистики, выведем графики
    # type = 1 : график по дням
    # group    : имя группы
    Doc->template('base')->{document_ready} .= <<AJAX;
        nody.ajax({
            a       : 'ajGraph',
            domid   : 'main_block',
            group   : '_graph_',
            y_title : '$cfg::gr',
            type    : 1
        });
AJAX
    return;
 }

 my $sql_where = $category>0? "category=$category" : 'cash>0';

 my $points = [];
 my $day = $days;
 my $sum = 0;
 my $tbl = tbl->new( -class=>'td_wide td_medium fade_border pretty' );
 while( $day >= 0 )
 {
    my %p = Db->line(
        'SELECT ABS(SUM(cash)) AS s, UNIX_TIMESTAMP(CURDATE() - INTERVAL ? DAY) AS tm '.
            "FROM pays WHERE $sql_where AND ".
            'time>=UNIX_TIMESTAMP(CURDATE() - INTERVAL ? DAY) AND '.
            'time<UNIX_TIMESTAMP(CURDATE() - INTERVAL ? DAY)',
        $day, $day, $day-1,
    );
    $day--;
    %p or next;
    $sum = 0 if !$need_sum;
    $sum += $p{s};
    if( $need_graph )
    {
        push @$points, [ 1000*$p{tm}, $sum ];
    }
     else
    {
        $tbl->add('*', 'lr', the_date($p{tm}), $sum);
    }
 }

 if( !$need_graph )
 {
    Show $tbl->show;
    return;
 }

 Save_webses_data(
    module=>'ajGraph', data=>{ points=>$points, group=>'_graph_', descr=>$categories->{$category} }
 );

 $url->redirect( days=>$days, category=>$category, sum=>$need_sum, graph=>1 );

}

1;