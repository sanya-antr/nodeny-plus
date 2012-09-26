#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::cap;
use strict;
use Debug;
use Db;
use nod::tasks;
use nod::httpd;
use nod::tmpl;

our @ISA = qw{kernel};

my $Param;
sub start
{
    my(undef, $single, $param) = @_;

    $Param = $param;

    my $httpd = nod::httpd->new( port => $param->{port} );
    $httpd->set_conditions(
        { condition => {},   sub => \&connection, },
    );
    $httpd->run();
}

sub connection
{
    my($connection) = @_;
    my $url = '?url='.filtr('http://'.$connection->{header}{host}.$connection->{header}{url});
    $url = '' if length($url) > 800;
    my $redirect = nod::tmpl::render( \$Param->{redirect}, url=>$Param->{url}.$url );
    $connection->send($redirect);
}

sub filtr
{
    local $_=shift;
    s|&|&amp;|g;
    s|<|&lt;|g;
    s|>|&gt;|g;
    s|'|&#39;|g;
    return $_;
}

1;