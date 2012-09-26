#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
    Adm->chk_privil_or_die('topology');

    my $date    = ses::input('date');        # Показываем авторизации в этот день
    my $minutes = ses::input_int('minutes'); # в эту отметку времени

    $date =~ s/ //g;
    my($day, $mon, $year, $time);
    if( $date )
    {
        ($day,$mon,$year) = split /\./, $date;
        eval{ $time = timelocal(0,0,0,$day,$mon-1,$year) };
        $time = 0 if $@;
    }
    $time ||= timelocal(0,0,0,$ses::day_now,$ses::mon_now-1,$ses::year_now-1900);
    $time += $minutes * 60;
    $time = $ses::t if $time>$ses::t;
 
    my $users = {};
    my $db = Db->sql("SELECT u.id, u.grp, d._gps FROM users u JOIN data0 d ON u.id = d.uid WHERE d._gps<>''");
    while( my %p = $db->line )
    {
        my $uid = $p{id};
        Adm->chk_usr_grp($p{grp}) or next;
        $p{_gps} =~ /^(\d+\.\d+),(\d+\.\d+)$/ or next;
        $users->{$uid} = [$1,$2];
    }

    my @users = ();
    my $db = Db->sql(
        "SELECT uid FROM (".
        " SELECT uid FROM auth_log WHERE start<=? AND end>?".
        " UNION ".
        " SELECT uid FROM v_ips WHERE auth>0 AND start<=?) AS tbl",
        $time, $time, $time,
    );
    while( my %p = $db->line )
    {
        my $uid = $p{uid};
        $users->{$uid} or next;
        push @users, $uid;
    }
    my $marks = join ',', map { "$_:{x:$users->{$_}[0],y:$users->{$_}[1]}" } @users;

    push @$ses::cmd, {
        type => 'js',
        data => "NoMap.show_marks('', {$marks})",
    };

    my $hh_mm = sprintf '%02d:%02d', int($minutes/60), $minutes % 60;
    push @$ses::cmd, {
        type => 'js',
        data => "NoMap.slider_ajax_end($minutes, '$hh_mm')",
    };
}

1;