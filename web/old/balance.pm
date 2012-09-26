#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (ñ) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::balance;
use strict;
use Time::localtime;
use Debug;
use Db;
use nomoney;

our @ISA = qw{kernel};

sub new
{
    my($M) = @_;
    $M->Task_add(
        task         => \&balance,
        period       => 5,
        first_period => 4,
    );
}

sub balance
{
    my($M, $task) = @_;
    my $db = Db->sql("SELECT * FROM fullusers WHERE actual=0");
    while( my %p = $db->get_line )
    {
        my $money_param = {
            paket     => $p{paket},
            start_day => $p{start_day},
            discount  => $p{discount},
            traf      => \%p,
            report    => 0,
        };

        my $money = nomoney->calc($money_param);

        my $final_balance = sprintf '%.2f', $p{balance} - $money->{money};
        if( $p{block_if_limit} && $p{state} eq 'on' &&  $final_balance < $p{limit_balance} )
        {
                Db->do_all(
                    [ "UPDATE users SET state='off' WHERE id=? LIMIT 1", $p{uid} ],
                    [ "INSERT INTO pays SET type=50, category=423, time=unix_timestamp(), mid=?, reason=?",
                        $p{uid}, "0:$final_balance:$p{limit_balance}"
                    ],
                );
        }

        Db->do(
            "UPDATE users_trf SET actual=1, submoney=?, traf1=?, traf2=?, traf3=?, traf4=? WHERE uid = ?",
            $money->{money}, $money->{traf}{1}, $money->{traf}{2}, $money->{traf}{3}, $money->{traf}{4}, $p{uid}
        );
    }

}

1;