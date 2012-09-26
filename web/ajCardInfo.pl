#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
    push @$ses::cmd, {
        id   => ses::input('domid'),
        data => _proc(),
    };

    return 1;
}

sub _proc
{
    Adm->chk_privil_or_die('SuperAdmin');
    $ses::auth->{adm}{trust} or return 'Сессия недоверенная, необходимо перелогиниться';
    my $cid = ses::input_int('cid');
    my %p = Db->line('SELECT * FROM cards WHERE cid=?', $cid);
    Db->ok or return $lang::err_try_again;
    %p or return "Информация по карте id = $cid не найдена";

    my $Fact = ses::input('act');

    $Fact eq 'status' && return $lang::card_alives->{$p{alive}};

    my $state;

    if( $Fact eq 'block_now' && $p{alive} ne 'activated' )
    {
        my $rows = Db->do("UPDATE cards SET alive='bad' WHERE cid=? AND alive<>'activated' LIMIT 1", $cid);
        $rows<1 && return $lang::err_try_again;
        $state = $lang::card_alives->{bad};
    }

    if( $Fact eq 'unblock' && $p{alive} eq 'bad' )
    {
        my $rows = Db->do("UPDATE cards SET alive='stock' WHERE cid=? AND alive='bad' LIMIT 1", $cid);
        
        $state = $lang::card_alives->{stock};
    }

    if( $state )
    {
        ToLog( '!! '.Adm->admin." changed card $cid state to ".$state );
        return $state;
    }

    my $url = url->new( a=>ses::cur_module, cid=>$cid, domid=>ses::input('domid'), -ajax=>1 );

    $Fact eq 'cod' && return $url->a($p{cod}, act=>'status');

    my $link =  $p{alive} eq 'bad'? $url->a('Разблокировать', act=>'unblock') :
                $p{alive} eq 'activated'? url->a('Активировал...', a=>'ajUserInfo', uid=>$p{uid_activate}, -ajax=>1 ) :
                $Fact eq 'block'? $url->a('Заблокировать?', act=>'block_now', -class=>'error') :
                $url->a('Заблокировать', act=>'block');
                
    return _('[p][p][p]',
        $url->a('Статус', act=>'status'),
        $url->a('Показать код', act=>'cod'),
        $link,
    );
}

1;