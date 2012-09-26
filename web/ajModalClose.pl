#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

push @$ses::cmd, {
    type => 'js',
    data => 'nody.modal_close();',
};

1;