#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

unshift @$ses::cmd, {
    id   => 'modal_window',
    data => _proc(),
};

return 1;

sub _proc
{
    return '<p>Клавиши:</p>'.
    '&darr; - смена типа поиска<br>'.
    'F2 - конвертация расскладки';
}

1;
