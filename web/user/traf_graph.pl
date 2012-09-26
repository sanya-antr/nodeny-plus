#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

# Модуль, выводящий график
my $_graph_mod = 'ajGraph';

sub go
{
 my($url,$usr) = @_;

 my $tm_stat = ses::input_int('tm_stat');
 ToLeft MessageWideBox( Get_list_of_stat_days('X', $url, $tm_stat) );

 {
    $tm_stat or last;

    my %p = Db->line("SELECT DATE_FORMAT(FROM_UNIXTIME(?), 'X%Y_%c_%e') AS t", $tm_stat);
    %p or return 1;
    my $traf_tbl_name = $p{t};

    my $sql = <<SQL;
    SELECT time, SUM(`in`) AS traf_in, SUM(`out`) AS traf_out FROM (
        SELECT time, `in`, `out` FROM $traf_tbl_name WHERE uid=?
            UNION
        SELECT time, 0, 0 FROM $traf_tbl_name WHERE uid = 0
    ) AS trf GROUP BY time ORDER BY time
SQL

    my $db = Db->sql( $sql, $usr->{id} );
    my $points = [];
    while( my %p = $db->line )
    {
        # все графики условно будут от 1 января 1970:
        # - разные дни будут накладываться друг на друга как один
        # - короткий timestamp
        my $gmtime = timegm(@{localtime($p{time})}[0..2],1,0,1970);
        push @$points, [ $gmtime, $p{traf_in} ];
    }

    my $descr = the_date($tm_stat);
    $descr .= url->a(" uid=".$usr->{id}, a=>'ajUserInfo', uid=>$usr->{id}, -ajax=>1) if $ses::auth->{role} eq 'admin';

    Save_webses_data(
        module=>$_graph_mod, data=>{ points=>$points, descr=>$descr, graph_id=>'usr_traf' }
    );
 }

 Doc->template('base')->{document_ready} .= <<AJAX;
    nody.ajax({
        a       : '$_graph_mod',
        domid   : 'main_block',
        graph_id: 'usr_traf',
        y_title : 'Входящий трафик'
    });
AJAX

}

1;
