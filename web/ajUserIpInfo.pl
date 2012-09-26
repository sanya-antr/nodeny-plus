#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

my $res = _proc();

$res && push @$ses::cmd, {
    id   => ses::input('domid'),
    data => _proc(),
};

return 1;

sub _proc
{
    my $uid = ses::input_int('uid');
    my $ipn = ses::input_int('ipn');

    my $err_msg = Adm->why_no_usr_access($uid);
    $err_msg && return $err_msg;

    my %p = Db->line("SELECT * FROM v_ips WHERE ipn=? AND uid=?", $ipn, $uid);
    %p or return 'Информация по ip не получена. Возможно параллельно были внесены изменения';

    my $url = url->new( a=>ses::cur_module, -ajax=>1, uid=>$uid, ipn=>$ipn, domid=>ses::input('domid') );

    my $tbl = tbl->new(-class=>'td_wide td_medium', -row1=>'row3', -row2=>'row3');
    $tbl->add('*', 'll', 'ip',           $p{ip});
    $tbl->add('*', 'll', 'Тип',          $p{type});
    $tbl->add('*', 'll', 'Авторизован',  $p{auth}? $lang::yes : $lang::no);
    if( $p{auth} )
    {
        $tbl->add('*', 'll', 'Старт авт.',        the_short_time($p{start}) );
        $tbl->add('*', 'll', 'Обновление авт.',   ($ses::t - $p{last}).' сек назад' );
        $tbl->add('*', 'll', 'Длительность авт.', the_hh_mm($ses::t - $p{start}) );
    }
     elsif( $p{type} eq 'dynamic' )
    {
        my $tm = $p{release} - $ses::t;
        $tbl->add('*', 'L', $tm>2? "Будет особожден через $tm секунд" : 'Будет освобожден с секунды на секунду');
    }
    if( $p{properties} ne '' )
    {
        my $properties = $p{properties};
        $properties =~ s/;/\n/g;
        $properties = v::filtr($properties);
        $properties =~ s/\n/<br>/g;
        $tbl->add('*','ll', 'Дополнительно', [$properties]);
    }

    my $urls = '';
    if( Adm->chk_privil(81) )
    {
        $urls = ses::input('del')? 
            $url->a('Уверены?', a=>'ajUserIpDel', -class=>'nav error' ) :
            $url->a('Удалить',  del=>1, -class=>'nav' );
        $urls .= ' ';
    }

    $urls .= $url->a('Закрыть', a=>'ajUserIpList', -class=>'nav');
    $tbl->add('', 'L', ['&nbsp;']);
    $tbl->add('', 'C', [ $urls ]);

    return Center($tbl->show);
}



1;