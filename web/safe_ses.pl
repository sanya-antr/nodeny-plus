#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
 my($url) = @_;
 Db->do('UPDATE websessions SET trust=0 WHERE BINARY ses=?', $ses::auth->{ses});

 url->redirect( -made=>"
    Правильно сделали, что переключились в безопасный режим - это ничего не меняет, кроме блокировки важных операций.
    Если отлучитесь от компа, никто не навредит."
 );

}
1;

