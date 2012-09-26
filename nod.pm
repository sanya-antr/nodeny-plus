#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use Time::HiRes qw( clock_gettime CLOCK_MONOTONIC gettimeofday tv_interval );
use Time::localtime;
use Getopt::Long;
use Debug;
use Db;
use nod::tasks;

my $help_msg = 
<<HELP;
    -v      : verbose
    -vv     : very verbose
    -d      : demonize
    -f=file : log file, default {{file_log}}
    -c=file : config file, default {{file_cfg}}
HELP

my $terminate;

my $_Tasks_   = {};
my $_Task_id_ = 0;

my $_Events_  = {};
my $_Event_id_= 0;

my $_Protect_ = {};

sub new
{
    my($M, %param) = @_;
    my $New = {%param};
    bless $New;
    return $New;
}

sub Start
{
    my($M) = @_;

    $_ = $help_msg;
    s/\{\{ *file_log *\}\}/$M->{file_log}/;
    s/\{\{ *file_cfg *\}\}/$M->{file_cfg}/;

    $M->{help_msg} .= $_;

    $cfg::dir_nod = $INC{'nod.pm'};
    $cfg::dir_nod = '' if $cfg::dir_nod !~ s|/+[^/]+$|/|;
    $cfg::dir_log = $cfg::dir_nod.'logs/';

    $M->{cmd_line_options} ||= {};
    
    my($v,$vv,$demonize,$help);
    GetOptions(
        'v'      => \$v,
        'vv'     => \$vv,
        'f=s'    => \$M->{file_log},
        'c=s'    => \$M->{file_cfg},
        'd'      => \$demonize,
        'h'      => \$help,
        %{$M->{cmd_line_options}}
    );

    $cfg::verbose = $vv? 2 : $v? 1 : 0;

    if( $M->{file_log} !~ m|^/| )
    {
        if( ! -d $cfg::dir_log )
        {
            mkdir $cfg::dir_log, 0700;
        }
        $M->{file_log} = $cfg::dir_log.$M->{file_log};
    }

    $M->{file_cfg} = $cfg::dir_nod.$M->{file_cfg} if $M->{file_cfg} !~ m|^/|;

    if( $help )
    {
        print $M->{help_msg};
        exit 1;
    }

    Debug->param(
        -type       => $demonize? 'file' : 'console',
        -file       => $M->{file_log},
        -nochain    => $cfg::verbose<2,
        -only_log   => $cfg::verbose<1,
    );

    $SIG{TERM} = $SIG{INT} = sub
    {
        tolog("Got the $_[0] sign");
        $terminate = 1;
    };

    $SIG{'__DIE__'} = sub
    {
        die @_ if $^S; # die внутри eval
        eval{ Hard_exit(undef,@_) };
        exit;
    };

    tolog('Start. Flag -h for help');
    tolog("loading $M->{file_cfg}");
    eval "
        require '$M->{file_cfg}';
    ";
    $@ && die $@;

    Db->new(
        host    => $cfg::Db_server,
        user    => $cfg::Db_user,
        pass    => $cfg::Db_pw,
        db      => $cfg::Db_name,
        timeout => $cfg::Db_connect_timeout,
        tries   => 3, # попыток с интервалом в секунду соединиться
        global  => 1, # создать глобальный объект Db, чтобы можно было вызывать абстрактно: Db->sql()
    );

    # периодически удаляем устаревшую инфу
    $M->Task_add(
        task         => \&_clean_myself_,
        period       => 60*60,
        first_period => 2,
    );

    return $M;
}

sub Sleep
{
    my($M, $sleep) = @_;
    $M->Task_run;
    $sleep = int($sleep * 100) || 100;
    map{ $terminate? 1 : select(undef,undef,undef,0.01) } ( 1..$sleep );
}

sub Hard_exit
{
    my($M, $msg) = @_;
    tolog($msg);
    sleep 2;
    exit 1;
}

sub Time
{
    return clock_gettime(CLOCK_MONOTONIC);
}

sub Is_terminated
{
    return $terminate;
}

sub _clean_myself_
{
    my($M, $task) = @_;
    my $del_time = int($M->Time - 60*60);
    foreach my $m( keys %$_Protect_ )
    {
        foreach my $key( keys %{$_Protect_->{m}} )
        {
            $_Protect_->{$m}{$key} < $del_time && delete $_Protect_->{$m}{$key};
        }
    }
}

# -----------------     Задачи    -----------------

# Постановка задачи в очередь
# task          - ссылка на подпрограмму (задачу)
# task_del      - ссылка на подпрограмму, которая будет вызвана перед удалением задачи
# period        - период выполнения задачи, сек
# first_period  - первый период выполнения задачи
# run_limit     - количество раз, которое будет выполнена задача, 0 - неограничено
sub Task_add
{
    my($M, %p) = @_;
    $p{period} = int($p{period}) || 1;
    $p{run_limit} = int $p{run_limit};
    $_Tasks_->{$_Task_id_} = {
        object  => $M,
        module  => ref $M,
        task_id => $_Task_id_,
        runtime => $M->Time + (defined $p{first_period}? $p{first_period} : $p{period}),
        %p
    };
    $_Task_id_++;
}

sub Task_del
{
    my($M, $task_id) = @_;
    my $task = $_Tasks_->{$task_id};
    ref $task or return;
    if( ref $task->{task_del} )
    {
        eval{ &{ $task->{task_del} }($task->{object}, $task) };
        $@ && debug('error', $@);
    }
    delete $_Tasks_->{$task_id};
}

sub Task_run
{
    my($M) = @_;
    my($runs);
    while( !$terminate )
    {
        $runs = 0;
        foreach my $task( values %$_Tasks_ )
        {
            $task->{runtime} > $M->Time && next;

            # накапливаем время, на которое задача пожже запустилась
            #$_Stat_->{$task->{module}} += $task->{runtime} - $now;

            eval{ &{ $task->{task} }($task->{object}, $task) };
            $@ && debug('error', $@);

            $runs++;

            if( $task->{run_limit} == ++$task->{runs} )
            {
                $M->Task_del( $task->{task_id} );
            }
             else
            {
                $task->{runtime} = $M->Time + $task->{period};
            }
        }
        # если не было запуска ни одной задачи - спим больше чтоб не нагружать процессор
        select(undef,undef,undef,$runs? 0.001 : 0.05);
    }
}

# -----------------     События    -----------------

sub Event_add
{
    my($M, $event, $event_ref) = @_;
    my $event_id = $_Event_id_++;
    $_Events_->{$event}{$event_id} = $event_ref;
    return $event_id;
}

sub Event_del
{
    my($M, $event, $event_id) = @_;
    delete $_Events_->{$event}{$event_id};
}

sub Event_run
{
    my($M, $event) = @_;
    my $events = $_Events_->{$event};
    foreach my $event_ref( values %$events )
    {
        &{$event_ref}(@_);
    }
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
    $M->Protect_time(3, 'usr_info', $uid) or return;
    Db->sql("SELECT ... WHERE uid =?", $uid);
    ....
}
=cut
sub Protect_time
{
    my $M = shift;
    my $timeout = shift;
    my $key = join '\0', @_;
    $_Protect_->{$M} ||= {};
    $_Protect_->{$M}{$key} > $M->Time && return 0;
    $_Protect_->{$M}{$key} = int($M->Time + $timeout);
    return 1;
}
1;
