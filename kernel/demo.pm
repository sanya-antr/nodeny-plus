#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::demo;
use strict;
use Debug;
use Db;
use nod::tasks;

our @ISA = qw{kernel};

my $Count = 0;

sub start
{
    my(undef, $single, $param) = @_;

    # $single установлен, если модуль запускается эксклюзивно, без других модулей
    # $param - параметры из файла cfg.pm

    nod::tasks->new(
        task         => \&main,
        period       => 1,
        first_period => $single? 0 : 5,
        run_limit    => 25,
        task_del     => \&task_end,
    );
}

sub main
{
    debug(++$Count);
    if( nod::tasks->protect_time(10, 'protect1') )
    {
        debug('Это сообщение выводится каждые 10 секунд');
    }
    if( nod::tasks->protect_time(4, 'protect2') )
    {
        debug('Это сообщение выводится каждые 4 секунды');
    }
}

sub task_end
{
    debug('Задача завершена');
}

1;