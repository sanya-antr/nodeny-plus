#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# cd /usr/ports/converters/p5-JSON-XS && make install clean
=head

Для клиента $F{uid} возвращает варианты допданных для поля с алиасом = $F{alias}

$F{x} и $F{y} - верхняя левая позиция модального окна, устанавливаются nody.js
при клике по ajax ссылке.

$F{orig_x} и $F{orig_y} - более приоритетная позиция модального окна, используется
когда ajax ссылка была в модальном окне, т.е был вызов модального окна из модального.

=cut

use strict;
use vars qw( $OUT %F $DOC $Url $Adm $Ugrp );
use Data;


$ses::json = [];

my $Fuid = int $F{uid};
my $Falias = $F{alias};
my $Finame = $F{iname};             # имя <input> поля, в которое будет записан один из предложенных вариантов
$Finame =~ s|["'\\]||g;             # javascript

my $fields = Data->get_fields($Fuid);

my $field = $fields->{$Falias};
if( ! ref $field )
{
    debug("Допполя с именем `$Falias` не существует");
    return 1;
}

my $out = '';
my $variants = $field->variant();

if( scalar @$variants > 10 && $F{var} eq '' )
{   # Много вариантов - выведем только начальные буквы существующих вариантов
    my %var1 = map{ substr($_->{descr},0,1) => 1 } @$variants;
    # еще сгруппируем по первым 3м буквам
    my %var3;
    map{ $var3{substr($_->{descr},0,3)}++ } @$variants;
    my @var = ();
    push @var, $_ foreach( sort{ $a cmp $b } keys %var1);
    push @var, $_ foreach( sort{ $var3{$a} <=> $var3{$b} } grep{ $var3{$_}>2 } keys %var3);
    $out .= '<br>';
    my $i = 0;
    foreach my $var( @var )
    {
        $out .= ' '.$Url->a($var,
            -class  =>'ajax',
            orig_x  => $F{x}+0,
            orig_y  => $F{y}+0,
            uid     => $Fuid,
            var     => $var,
            alias   => $Falias,
            iname   => $Finame,
        );
        $i++ < 6 && next;
        $i = 0;
        $out .= '<br>';
    }
    $out = _('[div big]',$out);
}
 else
{
    foreach my $var( @$variants )
    {
        $F{var} && $var->{descr} !~ /^$F{var}/ && next;
        $out .= url->a( $var->{descr}, -base=>'#', -onclick => "nody.set_field('$Finame','$var->{value}'); nody.modal_close(); return false;" ); 
    }
    $out = _('[div navmenu]',$out);
}

$out = $lang::ajDataVariant_title.' `'.$field->{title}.'`' . $out;

push @$ses::json, {
    id  => 'modal_window',
    x   => ($F{orig_x} || $F{x})+0,
    y   => ($F{orig_y} || $F{y})+0,
    data => $out,
};

return 1;

1;
