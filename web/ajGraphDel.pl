#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head
    Удаляет из БД графики с группой = ses::input('group'),
    после чего делает перерисовку графиков в ses::input('domid')
=cut

use strict;

sub go
{
 my $group = ses::input('group');

 my($role, $aid) = ($ses::auth->{role}, $ses::auth->{uid});
 # Выборка всех графиков текущего админа/юзера
 my @sql = ("SELECT * FROM webses_data WHERE role=? AND aid=? AND module=? ", $role, $aid, 'ajGraph');

 # Если указан unikey конкретного графика
 if( ses::input('id') )
 {
    $sql[0] .= ' AND unikey=?';
    push @sql, ses::input('id');
 }

 my $db = Db->sql( @sql );
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
    Db->sql("DELETE FROM webses_data WHERE role=? AND aid=? AND BINARY unikey=?", $role, $aid, $p{unikey});
 }
 my $domid = ses::input('domid');
 $domid =~ s/'/\\'/g;
 $group =~ s/'/\\'/g;
 my $type = ses::input_int('type');
 # Обновим графики в dom id = $domid
 push @$ses::cmd, {
    type => 'js',
    data => "nody.ajax({ a:'ajGraph', domid:'$domid', group:'$group', y_title:'', type:'$type' });",
 };
}

1;
