#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# Обработка нажатия на кнопку `ознакомлен` на сообщение клиенту
use strict;

sub go
{
    my($url,$usr) = @_;
    Db->do("UPDATE pays SET category=481 WHERE id=? AND mid=? AND category=480 LIMIT 1", ses::input_int('id'), $usr->{id});
    push @$ses::cmd, {
        id   => ses::input('domid'),
        data => _('[p]', 'Спасибо'),
    };
}

1;