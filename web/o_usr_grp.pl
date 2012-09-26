#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package op;
use strict;
use Debug;

my $d = {
    name        => 'группы клиентов',
    table       => 'user_grp',
    field_id    => 'grp_id',
    priv_show   => 'Admin',
    priv_edit   => 'SuperAdmin',
    priv_copy   => 'SuperAdmin',
    allow_copy  => 1,
    sql_get     => 'SELECT g.*, COUNT(u.grp) AS clients FROM user_grp g LEFT JOIN users u ON g.grp_id=u.grp '.
                    'WHERE g.grp_id=? GROUP BY g.grp_id',
    menu_create => 'Новая группа',
    menu_list   => 'Все группы', 
};


sub o_start
{
 return $d;
}

sub o_list
{
 Doc->template('top_block')->{title} = 'Клиентские группы';

 my $sort = ses::input_int('sort');
 my $url = $d->{url}->new( sort=>$sort );
 my $order_by = ('grp_name','grp_id','clients DESC')[$sort] || 'grp_name';
 my $sql = "SELECT g.*,COUNT(u.grp) AS clients FROM user_grp g LEFT JOIN users u ON g.grp_id=u.grp GROUP BY g.grp_id ORDER BY $order_by";
 my($sql,$page_buttons,$rows,$db) = main::Show_navigate_list($sql, ses::input_int('start'), 22, $url);

 $rows>0 or Error_("В базе данных нет ни одной группы клиентов[p h_center]",
    $url->a('Создать', op=>'new', -class=>'nav')
 );

 my $tbl = $d->{tbl};
 $tbl->add('head td_tall', 'ccc3',
    [$url->a('Id группы', sort=>1)],
    [$url->a('Название', sort=>0)],
    [$url->a('Клиентов в группе', sort=>2)],
    'Операции',
 );

 while( my %p = $db->line )
 {
    $tbl->add('*', 'clcccc',
        $p{grp_id},
        $p{grp_name},
        $p{clients},
        $d->btn_edit($p{grp_id}),
        $d->btn_copy($p{grp_id}),
        $p{clients}<1 && $d->btn_del($p{grp_id}),
    );
 }

 Show $page_buttons.$tbl->show.$page_buttons;
}


sub o_edit
{
 $d->{name_full} = _('группы [filtr|commas|bold]', $d->{d}{grp_name});
 # запрет на удаление
 $d->{no_delete} = 'в группе есть клиенты. Переведите их в другую группу' if $d->{d}{clients}>0;
}

sub o_new
{
 }

sub o_show
{
 my %grp_property = map{ $_ => 1} split /,/, $d->{d}{grp_property};

 my $tbl = tbl->new( -class=>'td_wide td_tall pretty' );

 $tbl->add('*','ll',
    [ v::input_t( name=>'grp_name', value=>$d->{d}{grp_name}) ],
    'Название группы',
 );

 $tbl->add('*','ll',
    [ v::checkbox( name=>'grp_property', value=>5, checked=>$grp_property{5}) ],
    'Запретить администраторам переводить клиентов этой группы в иную',
 );

 $tbl->add('*','ll',
    [ v::input_t( name=>'grp_block_limit', value=>$d->{d}{grp_block_limit}) ],
    "Лимит отключения для создаваемых учетных записей клиентов, $cfg::gr",
 );

 $tbl->add('*','L',
    [ _('[p][p][]',
        'Перечислите допустимые подсети в формате xx.xx.xx.xx/yy.',
        'Если ни одна сеть не будет указана, то в данной группе будут допустимы любые ip',
        v::input_ta('grp_nets', $d->{d}{grp_nets}, 60, 6)
    ) ],
 );

 $d->chk_priv('priv_edit') && $tbl->add('','C', [ v::submit($lang::btn_save) ]);

 Show Center $d->{url}->form( id=>$d->{id}, $tbl->show );
}

sub o_update
{
 $d->{sql} .= 'SET grp_name=?, grp_property=?, grp_block_limit=?, grp_nets=?';

 push @{$d->{param}}, v::trim(ses::input('grp_name')) || 'NoDeny';
 push @{$d->{param}}, ','.ses::input('grp_property').',';
 push @{$d->{param}}, ses::input('grp_block_limit') + 0;

 my $grp_nets = ses::input('grp_nets');
 $grp_nets =~ s|\s*,\s*|\n|g;
 $grp_nets =~ s|\s+|\n|g;
 push @{$d->{param}}, $grp_nets;
}

sub o_insert
{
 return o_update(@_);
}

1;
