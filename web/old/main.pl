#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use vars qw( %F $Url $Adm );

my $out = '';
$out .= $Url->a('Личные настройки', a=>'mytune') if !$Adm->{pr}{108};
$out .= $Url->a('Новый клиент', a=>'user') if $Adm->{pr}{88};
$out .= $Url->a('Карта', a=>'yamap') if $Adm->{pr}{topology};
$out .= $Url->a('Фин. отчет', a=>'report') if $Adm->{pr}{fin_report};
$out .= $Url->a('Карточки пополнения счета', a=>'cards') if $Adm->{pr}{cards};
$out .= $Url->a('Администраторы', a=>'admin') if $Adm->{pr}{SuperAdmin};
$out .= $Url->a('Настройки', a=>'tune') if $Adm->{pr}{SuperAdmin};

Doc->template('base')->{left_block} = Menu($out);


1;
