#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use vars qw( %F $Url $Ugrp );

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
    $F{mark_id} =~ /^([up])(\d+)$/ or return "`$F{mark_id}` - некорректный id маркера";
    $1 eq 'p' && return _proc_place($2);
    $1 eq 'u' && return _proc_user($2);
    return 'local error';
}

sub _proc_user
{
    my($uid) = @_;
    my $info = Get_usr_info($uid) or return $lang::err_try_again;
    $info->{id} or return "User id=$uid не найден в базе";
    Adm->chk_usr_grp($info->{grp}) or return "Нет доступа к группе user id=$uid";
    return $info->{full_info};
}

sub _proc_place
{
    my($id) = @_;
    my %u = Db->line("SELECT * FROM places WHERE id=?", $id);
    Db->ok or return $lang::err_try_again;
    %u or return "Место id=$id не найдено в базе";
    return v::filtr($u{location});
}

1;