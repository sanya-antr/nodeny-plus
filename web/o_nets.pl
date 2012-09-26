#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package op;
use strict;
use Debug;

my $d = {
    name        => 'сети',
    table       => 'nets',
    field_id    => 'id',
    priv_show   => 'Admin',
    priv_edit   => 'SuperAdmin',
    priv_copy   => 'SuperAdmin',
    allow_copy  => 1,
    sql_get     => "SELECT * FROM nets WHERE id=?",
    menu_create => 'Добавить сеть',
    menu_list   => 'Все сети', 
};


sub o_start
{
 return $d;
}


sub o_list
{
 Doc->template('top_block')->{title} = 'Список сетей';

 my $tbl = $d->{tbl};
 my $url = $d->{url}->new();

 my $sql = "SELECT * FROM nets ORDER BY priority";
 my $db = Db->sql($sql);

 if( $db->rows < 1)
 {
    Error( 'В базе данных пока нет ни одной сети' );
 }

 while( my %p = $db->line )
 {
    my $traf_name = $cfg::trafname{$p{class}};
    $tbl->add('*', [
        [ '',           'Приоритет',    $p{priority}            ],
        [ '',           'Сеть',         $p{net}                 ],
        [ '',           'Порт',         $p{port}                ],
        [ '',           'Направление',  $traf_name              ],
        [ '',           'Комментарий',  $p{comment}             ],
        [ 'h_center',   '',             $d->btn_edit($p{id})    ],
        [ 'h_center',   '',             $d->btn_del($p{id})     ],
    ]);
 }

 Show $tbl->show;
}


sub o_new
{
 $d->{d}{priority} = 100;
 $d->{d}{class} = 1;
}

sub o_edit
{
 $d->{name_full} = _('сети [bold]', $d->{d}{net});
}


sub o_show
{
 my $tbl = tbl->new( -class=>'data_input_tbl' );

 my $traf_cls = v::select(
    name     => 'class',
    size     => 1,
    selected => $d->{d}{class},
    options  => [ map{ $_ => $cfg::trafname{$_} } sort{ $a <=> $b }keys %cfg::trafname ],
 );

 $tbl->add('', 'll', 'Приоритет',   [ v::input_t( name=>'priority', value=>$d->{d}{priority} ) ]);
 $tbl->add('', 'll', 'Направление', [ $traf_cls ] );
 $tbl->add('', 'll', 'Сеть',        [ v::input_t( name=>'net', value=>$d->{d}{net} ) ]);
 $tbl->add('', 'll', 'Порт',        [ v::input_t( name=>'port', value=>$d->{d}{port} ) ]);
 $tbl->add('', 'll', 'Комментарий', [ v::input_t( name=>'comment', value=>$d->{d}{comment} ) ]);

 $d->chk_priv('priv_edit') && $tbl->add('', 'C', [ v::submit($lang::btn_save) ]);

 Show Center $d->{url}->form($tbl->show);
}


sub o_update
{
 my($net, $comment) = ses::input('net', 'comment');
 my($class, $port, $priority) = ses::input_int('class', 'port', 'priority');

 $net =~ s/\s//g;
 my $mask = $net !~ s|\/(\d+)$||? 32 : $1>32? 32 : $1;
 $net =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/ or Error('Необходимо задать сеть в виде xx.xx.xx.xx/xx');
 my $net_raw = pack('CCCC',$1,$2,$3,$4);
 my $mask_raw = pack('B32', 1 x $mask, 0 x (32-$mask));
 (($net_raw & $mask_raw) ne $net_raw) &&
    Error('Сеть задана неверно: неверен побитовый AND с сетью и маской подсети. '.
        'Например, нельзя 10.0.0.1/24, нужно 10.0.0.0/24');
 $net .= "/$mask";

 # Ошибку не пишем т.к ввод через выпадающий список, значит подделка
 $class = 0 if $class<0 || $class>4;

 $d->{sql} = "SET net=?, class=?, port=?, priority=?, comment=?";
 push @{$d->{param}}, $net, $class, $port, $priority, $comment;
}

sub o_insert
{
 return o_update(@_);
}


1;
