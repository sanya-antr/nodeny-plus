#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package nod::tasks;
use strict;
use Time::HiRes qw( clock_gettime CLOCK_MONOTONIC gettimeofday tv_interval );
use Debug;

my $Tasks   = {};
my $Task_id = 0;

my $Protect = {};

my $Term_sub;

sub register_term_sub
{
    shift;
    $Term_sub = shift;
}

# -----------------     Постановка задачи в очередь    -----------------
# 
# task          - ссылка на подпрограмму (задачу)
# task_del      - ссылка на подпрограмму, которая будет вызвана перед удалением задачи
# period        - период выполнения задачи, сек
# first_period  - первый период выполнения задачи
# run_limit     - количество раз, которое будет выполнена задача, 0 - неограничено
# param         - параметры, которые можно передать задаче
sub new
{
    shift;
    my $task = {@_};
    bless $task;
    my $task_id = "$task";
    $task->{param} ||= {};
    $task->{id} = $task_id;
    $task->{period} = int($task->{period}) || 1;
    $task->{run_limit} = int $task->{run_limit};
    $task->{runtime} = _time() + (defined $task->{first_period}? $task->{first_period} : $task->{period});
    $Tasks->{$task_id} = $task;
}

sub destroy
{
    my($task) = @_;
    ref $task or return;
    if( ref $task->{task_del} )
    {
        eval{ &{ $task->{task_del} }($task, $task->{param}) };
        $@ && debug('error', $@);
    }
    delete $Tasks->{$task->{id}};
}

sub run
{
    my($runs);
    while( 1 )
    {
        $Term_sub && &{$Term_sub}() && return;
        $runs = 0;
        foreach my $task( values %$Tasks )
        {
            $task->{runtime} > _time() && next;
            $runs++;

            eval{ &{ $task->{task} }($task, $task->{param}) };
            $@ && debug('error', $@);

            if( $task->{run_limit} == ++$task->{runs} )
            {
                $task->destroy();
            }
             else
            {
                $task->{runtime} = _time() + $task->{period};
            }
        }
        # если не было запуска ни одной задачи - спим больше чтоб не нагружать процессор
        select(undef,undef,undef,$runs? 0.001 : 0.05);
    }
}

sub _time
{
    return clock_gettime(CLOCK_MONOTONIC);
}

# -----------------     Защиты    -----------------

# Защита от чрезмерно частого выполнения действия
# Например, следующим мы запретим выборку данных из БД
# конкретного клиента с id = $uid чаще одного раза в 3 секунды
# здесь ('usr_info', $uid) - ключевые данные
=head
sub get_usr_info
{
    my($uid) = @_;
    if( nod::tasks->protect_time(3, 'usr_info', $uid) )
    {
        Db->sql("SELECT ... WHERE uid=?", $uid);
    }
    ....
}
=cut

sub protect_time
{
    shift;
    my $timeout = shift;
    my $key = join '\0', @_;
    #$Protect->{...} ||= {};
    $Protect->{$key} > _time() && return 0;
    $Protect->{$key} = int(_time() + $timeout);
    return 1;
}

1;
