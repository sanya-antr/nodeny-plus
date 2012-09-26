#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head1 INFO
    Плагин удаления временных платежей.
    После удаления пишется событие в таблицу платежей.
=cut

package kernel::tmppays;
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
        period       => 5*60,
        first_period => $single? 0 : 60,
    );
}

sub main
{
    my $db = Db->sql("SELECT mid, id, cash FROM pays WHERE category=3 AND time<UNIX_TIMESTAMP()");
    while( my %p = $db->line )
    {
        Db->do_all(
            [ "DELETE FROM pays WHERE id=? LIMIT 1", $p{id} ],
            [ "UPDATE users SET balance=balance-(?) WHERE id=? LIMIT 1", $p{cash}, $p{mid} ],
            [ "INSERT INTO pays SET creator='kernel', category=200, time=UNIX_TIMESTAMP(), mid=?, reason=?",
                $p{mid}, $p{cash}
            ],
        )>0 or next;
        tolog("Удален временный платеж $p{cash} $cfg::gr клиента id=$p{mid}");
    }
}

1;