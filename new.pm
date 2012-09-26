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

    $cfg::dir_nod = $INC{'nod.pm'} || $INC{'new.pm'};
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

    nod::tasks->register_term_sub( \&Is_terminated );
}

sub Hard_exit
{
    my(undef, $msg) = @_;
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




1;
