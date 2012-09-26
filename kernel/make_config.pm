#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::make_config;
use strict;
use Debug;
use Db;
use nod::tasks;
use nod::tmpl;

our @ISA = qw{kernel};

sub start
{
    my(undef, $single, $param) = @_;

    nod::tasks->new(
        task         => \&main,
        period       => 3600,
        first_period => $single? 0 : 8,
    );
}

sub main
{
    debug($cfg::dir_nod);
    my %users = {};
    my @users = ();
    my $db = Db->sql("SELECT * FROM fullusers");#, $cfg::Passwd_Key);
    $db->ok or return;
    while( my %p = $db->line )
    {
        $p{ips} = [];
        push @users, \%p;
        $users{$p{id}} = \%p;
    }
    my $db = Db->sql("SELECT *, INET_NTOA(ip) AS ipa FROM ip_pool WHERE uid>0");
    $db->ok or return;
    while( my %p = $db->line )
    {
        my $uid = $p{uid};
        exists $users{$uid} or next;
        push @{$users{$uid}->{ips}}, \%p;
    }

    #debug(\@users);
    tolog( nod::tmpl::render($cfg::dir_nod.'/kernel/make_config/dhcp.tmpl', users => \@users ) );
}



1;