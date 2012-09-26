#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use Socket;

push @$ses::cmd, {
    id   => ses::input('domid'),
    data => _proc(),
};

return 1;

sub _proc
{
    my $ip = ses::input('ip');
    return gethostbyaddr(inet_aton($ip), AF_INET).'<br>'.$ip;
}

1;