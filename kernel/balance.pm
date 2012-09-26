#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::balance;
use strict;
use Debug;
use Db;
use nod::tasks;

our @ISA = qw{kernel};

sub start
{
    my(undef, $single, $param) = @_;

    nod::tasks->new(
        task         => \&main,
        period       => $param->{period} || 7,
        first_period => $single? 0 : 4,
    );
}

sub main
{
    my $db = Db->sql("SELECT id,balance,limit_balance FROM users WHERE block_if_limit=1 AND balance<limit_balance AND state='on'");
    while( my %p = $db->line )
    {
        my $ok = Db->do_all(
            [   "UPDATE users SET state='off' WHERE id=? LIMIT 1", $p{id} ],
            [   "INSERT INTO pays SET creator='kernel', category=423, time=UNIX_TIMESTAMP(), mid=?, reason=?",
                    $p{id}, "$p{balance}:$p{limit_balance}"
            ],
        );
        $ok && tolog("Заблокирован доступ клиенту id=$p{id}, баланс $p{balance} < $p{limit_balance}");
    }
}

1;