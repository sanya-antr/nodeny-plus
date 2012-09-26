#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package op;
use strict;

my $d = {
    name        => 'учетной записи клиента',
    table       => 'users',
    field_id    => 'id',
    priv_show   => 'Admin',
    priv_edit   => 'SuperAdmin',
    priv_copy   => 'SuperAdmin',
    allow_copy  => 1,
    sql_all     => "SELECT * FROM users ORDER BY id",
    sql_get     => "SELECT * FROM users WHERE id = ?",
    create_str  => 'Новая запись',
    list_str    => 'Все записи', 
};

sub o_start
{
 return $d;
}


1;
