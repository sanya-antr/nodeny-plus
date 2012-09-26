#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
#/usr/ports/net/p5-Net-DHCP
package kernel::dhcp_server;
use strict;
use Debug;
use Db;
use nod::tasks;

use Net::DHCP::Packet;
use Net::DHCP::Constants;
use IO::Socket;
use IO::Select;

our @ISA = qw{kernel};


sub start
{
    my(undef, $single, $param) = @_;

    my $bind_ip = inet_aton('0.0.0.0');
    my $bind_port = 67;

    my $proto = getprotobyname('udp');
    
    socket( SOCKET, PF_INET, SOCK_DGRAM, $proto ) or die 'Socket create error';
    bind( SOCKET, sockaddr_in($bind_port, INADDR_ANY) ) or die "Can't bind to port $bind_port!";

    my $rin = '';
    vec($rin, fileno(SOCKET), 1) = 1;

    while( ! kernel->Is_terminated )
    {
        while( select(my $pkt=$rin,undef,undef,0) )
        {
            $pkt = '';
            my $fromaddr = recv(SOCKET, $pkt, 16384, 0);
            debug($pkt);
            $! && next;

            my $pkt = decode_pkt($pkt);

            debug($pkt);

            
        }
    }
}

sub decode_pkt
{
    my($pkt) = @_;
    my $pkt_len = length $pkt;

    length($pkt) < 236 && return 'Слишком маленький пакет';

    my $dhcpreq = new Net::DHCP::Packet($pkt);

    $dhcpreq->op() != BOOTREQUEST && return 'Принимаем только request-пакеты, а это reply';

    $dhcpreq->isDhcp() == 0 && return 'Это не DHCP запрос, возможно BOOTP';

    $dhcpreq->htype() != HTYPE_ETHER && return 'Тип аппаратного адреса не ethernet';

    $dhcpreq->hlen() != 6 && return 'Длина мак-адреса должна быть 6 байт';
}

1;
