#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use nod::liqpay;

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
    Adm->chk_privil('SuperAdmin') or return '1000000$';

    my %p = nod::liqpay::API(
        action      => 'view_balance',
        merchant_id => $cfg::liqpay_merch_id,
    );

    if( $p{error} || ! ref $p{result}->{balances} )
    {
        debug($p{error} || $p{result});
        return 'Не удалось получить балансы Liqpay-мерчанта';
    }

    return join '<br>', 'Балансы Liqpay-мерчанта:', map{ $p{result}->{balances}{$_} . ' ' . $_ } keys %{$p{result}->{balances}};
}

1;