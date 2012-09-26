#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# ajYamapMove
# ajYamapCreate
use strict;
use vars qw( %F $Ugrp );
use web::Data;

if( ses::input('no') )
{
    push @$ses::cmd, {
        type => 'js',
        data => 'NoMap.close_balloon()',
    };
    return 1;
}

# 1. Шлем js команду открыть балун, в котором div с id='mballoon'
# 2. Шлем команду записать $msg в div
# 3. Шлем js команду перерисовать балун (отобразится $msg) и
#    сделать все ссылки ajax-совыми ( live не работает в yandex maps :( )

my $gps = ses::input('gps');
push @$ses::cmd, {
    type => 'js',
    data => "NoMap.open_ballon($gps)",
};
push @$ses::cmd, {
    id   => 'mballoon',
    data => _proc(),
};
push @$ses::cmd, {
    type => 'js',
    data => 'NoMap.update_ballon()',
};

return 1;

sub _proc
{
    ses::input('gps') =~ /^(\d+\.\d+),(\d+\.\d+)$/ or return 'Неверные координаты';
    my $mark_id = ses::input('mark_id');
    $mark_id =~ /^([up])(\d+)$/ or return "`$mark_id` - некорректный id маркера";
    $1 eq 'p' && return _proc_place($2, $mark_id);
    $1 eq 'u' && return _proc_user($2, $mark_id);
    return 'local error';
}

sub _proc_user
{
    my($uid, $mark_id) = @_;

    Adm->chk_privil(80) or return 'Нет привелегии изменения допданных';

    my %u = Db->select_line("SELECT grp FROM users WHERE id=?", $uid);
    Db->ok or return $lang::err_try_again;
    %u or return "User id=$uid не найден в базе";
    Adm->chk_usr_grp($u{grp}) or return "Нет доступа к группе user id=$uid";

    my $fields = Data->get_fields($uid);
    my $Gps = $fields->{_gps} or return 'Нет допполя с именем `_gps`';

    my($origX, $origY) = $Gps->{value} =~ /^(\d+\.\d+),(\d+\.\d+)$/? ($1, $2) : (0,0);
    my($gpsX, $gpsY) = split /,/, ses::input('gps');

    {
        ses::input('yes') && last;
        ses::input('a') eq 'ajYamapCreate' && !$origX && last;
        my $q = ses::input('a') eq 'ajYamapMove'? 'Переместить клиента в новые координаты?' :
                    url->a("Клиент с id=$uid", a=>'ajYamapBalloon', uid=>$uid, -class=>'ajax').
                        ' уже имеет gps координаты. Установить новые?';
        return _('[p][]', $q,
            Center( 
                url->a($lang::yes, %F, yes=>1, -class=>'nav', -ajax=>1).' '.
                url->a($lang::no, %F, no=>1, -class=>'nav', -ajax=>1)
            )
        );
    }

    $Gps->{new_value} = ses::input('gps');
    my $err = Data->save($fields);
    if( $err )
    {
        debug('error', 'при сохранении данных модуль Data вернул ошибку:', $err);
        return 'Ошибка сохранения координат в БД';
    }

    push @$ses::cmd, {
        type => 'js',
        data => 'NoMap.close_balloon()',
    };

    my $unikey = ses::input('unikey');
    $unikey =~ s/['\\]//g;
    push @$ses::cmd, {
        type => 'js',
        data => "NoMap.reload_marks('$unikey')",
    };

    Exit();
}

sub _proc_place
{
    my($id, $mark_id) = @_;
    my %p = Db->select_line("SELECT * FROM places WHERE id=?", $id);
    Db->ok or return $lang::err_try_again;
    %p or return "Место id=$id не найдено в базе";
    
    {
        ses::input('yes') && last;
        ses::input('a') eq 'ajYamapCreate' && !$p{gpsX} && last;
        my $q = ses::input('a') eq 'ajYamapMove'? 'Переместить место в новые координаты?' :
                    url->a("Место с id=$id", a=>'ajYamapBalloon', mark_id=>$mark_id, -class=>'ajax').
                        ' уже имеет gps координаты. Установить новые?';
        return _('[p][]', $q,
            Center( 
                url->a($lang::yes, %F, yes=>1, -class=>'nav', -ajax=>1).' '.
                url->a($lang::no, %F, no=>1, -class=>'nav', -ajax=>1)
            )
        );
    }

    my($gpsX, $gpsY) = split /,/, ses::input('gps');
    Db->do("UPDATE places SET gpsX=?, gpsY=? WHERE id=?", $gpsX, $gpsY, $id);
}



1;