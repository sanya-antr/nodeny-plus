#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package op;
use strict;
use vars qw( %F );

my $d = {
    name        => 'точки топологии',
    table       => 'places',
    field_id    => 'id',
    priv_show   => 'topology',
    priv_edit   => 'edt_topology',
    priv_copy   => 'edt_topology',
    allow_copy  => 1,
    sql_get     => "SELECT * FROM places WHERE id=?",
    menu_create => 'Новая точка', 
    menu_list   => 'Все точки',
};


sub o_start
{
 return $d;
}

sub o_list
{
 Doc->template('top_block')->{title} = 'Точки топологии';
 my $tbl = tbl->new( -class=>'td_wide pretty' );
 my $url = $d->{url}->new();
 my $sql = "SELECT * FROM places ORDER BY id";
 my($sql,$page_buttons,$rows,$db) = main::Show_navigate_list($sql, ses::input_int('start'), 22, $url);
 $rows>0 or Error_("Пока не создано ни одной точки топологии.[br2][]",
    $url->a('Создать', op=>'new', -class=>'nav', -center=>1)
 );

 $tbl->add('head td_tall', 'lllllC', 'id', 'gpsX', 'gpsY', 'Местоположение', 'Описание', 'Операции');
 while( my %p = $db->line )
 {
    $tbl->add('*', 'lllllll',
        $p{id},
        $p{gpsX},
        $p{gpsY},
        $p{location},
        $p{descr},
        $d->btn_edit($p{id}),
        $d->btn_del($p{id}),
    );
 }
 Show $page_buttons.$tbl->show.$page_buttons;
}

sub o_new
{
}

sub o_edit
{
 $d->{name_full} = _('точки топологии [commas|bold] ([filtr])', $d->{d}{id}, $d->{d}{location});
}

sub o_show
{
 my $url = $d->{url};

 my $lines = [
    { type => 'text', name => 'id',         value => $d->{d}{id},       title => 'Id'               },
    { type => 'text', name => 'location',   value => $d->{d}{location}, title => 'Местоположение'   },
    { type => 'text', name => 'gpsX',       value => $d->{d}{gpsX},     title => 'gpsX'             },
    { type => 'text', name => 'gpsY',       value => $d->{d}{gpsY},     title => 'gpsY'             },
    { type => 'text', name => 'descr',      value => $d->{d}{descr},    title => 'Описание'         },
 ];

 if( $d->chk_priv('priv_edit') )
 {
    push @$lines, { type=>'submit', value=>$lang::btn_save };
 }

 Show Center $d->{url}->form($lines);
}

sub o_update
{
 $d->{sql} .= "SET location=?, descr=?, gpsX=?, gpsY=?";
 push @{$d->{param}}, ses::input('location'), ses::input('descr'), ses::input('gpsX'), ses::input('gpsY');
}

sub o_insert
{
 o_update(@_);
 $d->{sql} .= ", id=?";
 push @{$d->{param}}, ses::input_int('id');
}

1;
