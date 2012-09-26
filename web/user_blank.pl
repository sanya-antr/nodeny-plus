#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use web::Data;

my $Fuid = ses::input_int('uid');

my %tmpl = ();

my %p = Db->line("SELECT *, AES_DECRYPT(passwd,?) AS pass FROM users WHERE id=?", $cfg::Passwd_Key, $Fuid);
%p or Error($lang::err_try_again);

$tmpl{users} = \%p;

$tmpl{ips} = [];
my $db = Db->sql("SELECT ip,ipn FROM v_ips WHERE uid=? ORDER BY ip", $Fuid);
while( my %p = $db->line )
{
    push @{$tmpl{ips}}, \%p;
}

my $html = tmpl('user_blank', %tmpl);

print "Content-type: text/html\n\n";
print $html;
#print Debug->show;
exit;

1;
