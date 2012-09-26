#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
    Adm->chk_privil_or_die('topology');

    my $users = {};
    my @users = ();
    my $db = Db->sql("SELECT u.id, u.grp, d._gps FROM users u JOIN data0 d ON u.id = d.uid WHERE d._gps<>''");
    while( my %p = $db->line )
    {
        my $uid = $p{id};
        Adm->chk_usr_grp($p{grp}) or next;
        $p{_gps} =~ /^(\d+\.\d+),(\d+\.\d+)$/ or next;
        $users->{$uid} = [$1,$2];
        push @users, $uid;
    }

    my $unikey = ses::input('unikey');
    if( $unikey )
    {
        my %p = Db->line(
            "SELECT * FROM webses_data WHERE role=? AND aid=? AND unikey=? AND module='yamap'",
            $ses::auth->{role}, $ses::auth->{uid}, ses::input('unikey'),
        );
        %p or return;

        my $VAR1;
        my $data = eval $p{data};
        if( $@ )
        {
            debug('warn', "Ошибка парсинга данных по ключу `$p{unikey}`: $@");
            return;
        }
        ref $data eq 'HASH' or return;
        ref $data->{ids} eq 'ARRAY' or return;
        @users =  @{$data->{ids}};
    }

    my $marks = join ',', map { "$_:{x:$users->{$_}[0],y:$users->{$_}[1]}" } grep{ $users->{$_} } @users;

    $unikey =~ s/['\\]//g;
    push @$ses::cmd, {
        type => 'js',
        data => "NoMap.show_marks('$unikey', {$marks})",
    };
}

1;