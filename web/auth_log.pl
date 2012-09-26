#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head

Отображение графика количества авторизованных почасово в сутки

    date : дд.мм.гггг статистики

=cut
use strict;

sub go
{
 my($url) = @_;

 my $date = ses::input('date');
 $date =~ s/ //g;

 my($day, $mon, $year, $time);
 # проверим, что дата введена корректно
 if( $date )
 {
    ($day,$mon,$year) = split /\./, $date;
    eval{ $time = timelocal(0,0,0,$day,$mon-1,$year) };
    $date = '' if $@;
 }

 # --- Форма выбора даты и номера графика ---
 {
    my $form = $url->form( -method=>'get',
        v::input_t(name=>'date', value=>$date, class=>'dateinput').' '.v::submit('Показать')
    );

    ToRight MessageBox( $form );
 }

 if( !$date )
 {
    Doc->template('base')->{document_ready} .=
        "\n nody.ajax({ a:'ajGraph', domid:'main_block', group:'_auth_', y_title:'Количество авторизованных' });";
    return 1;
 }

 my $period = 4*60;
 my $half_period = int($period/2);

 my $points = [];
 my $sec = 0;
 while( $sec <= 3600*24 )
 {
    my $tm = $time+$sec;
    $tm > $ses::t && last;
    my $db = Db->sql(
        "SELECT SUM(n) AS s FROM (".
        " SELECT COUNT(*) AS n FROM auth_log WHERE start<=? AND end>?".
        " UNION ALL ".
        " SELECT COUNT(*) AS n FROM auth_now WHERE start<=?) AS tbl",
        $tm, $tm, $tm,
    );
    while( my %p = $db->line )
    {
        push @$points, [ $sec + $half_period, $p{s} ];
    }
    $sec += $period;
 }

 Save_webses_data(
    module=>'ajGraph', data=>{ points=>$points, group=>'_auth_', descr=>$date }
 );

 $url->redirect( graph_rough=>0 );
}

1;