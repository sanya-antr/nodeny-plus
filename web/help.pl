#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
 my $theme = ses::input('theme').'';

 $theme eq '' && Error('Тема помощи не задана');
 $theme =~ /\W/ && Error('Недопустимые символы в теме помощи');

 my $file = "$cfg::dir_web/help/$theme.html";

 if( !open(F, "<$file") )
 {
    debug('error', _($lang::cannot_load_file, $file));
    Error("Файл с темой `$theme` помощи не существует");
 }

 my $out = '';
 $out .= $_ while( <F> );
 return $ses::ajax? ajModal_window($out) : Show Box( msg=>$out, title=>'Справка' );
}

1;
