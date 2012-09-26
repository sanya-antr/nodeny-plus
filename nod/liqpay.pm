#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# cd /usr/ports/textproc/p5-XML-Simple && make install clean
# cd /usr/ports/security/p5-Digest-SHA1 && make install clean
# cd /usr/ports/www/p5-LWP-UserAgent-WithCache/ && make install clean
# cd /usr/ports/security/p5-Crypt-SSLeay/ && make install clean
# cd /usr/ports/www/p5-LWP-Protocol-https && make install clean

package nod::liqpay;

=head1 INFO
    Модуль взаимодействие с системой Liqpay
    
    На текущий момент доки по
        API: https://liqpay.com/?do=pages&p=api
        CnB: https://liqpay.com/?do=pages&p=cnb12

    Пример работы с API:

        my %p = nod::liqpay::API(
            action      => 'view_balance',
            merchant_id => $cfg::liqpay_merch_id,
        );
        $p{error} && Error( $p{error} );
        debug('pre', $p{result});

=cut

use strict;
use Debug;
use XML::Simple;
use MIME::Base64;
use Digest::SHA1 qw( sha1 sha1_hex );

$cfg::liqpay_api_url = 'https://www.liqpay.com/?do=api_xml';

sub CnB
{
    my %p = @_;
    my $sxml = XML::Simple->new() or return( error=>'xml making error' );
    my $request = {
        version     => [ 1.2 ],
        merchant_id => [ $p{merchant_id}    ],
        result_url  => [ $p{result_url}     ],
        server_url  => [ $p{server_url}     ],
        amount      => [ $p{amount}         ],
        currency    => [ $p{currency}       ],
        order_id    => [ $p{order_id}       ],
        description => [ $p{description}    ],
        exp_time    => [ $p{exp_time}       ],
        pay_way     => [ $p{pay_way}        ],
    };
    my $xml = $sxml->XMLout( $request, RootName=>'request' );
    debug('pre', $xml);
    my $signature = _signature($xml); 
    my $operation_xml = encode_base64($xml);
    chomp $operation_xml;
    return(
        operation_xml => $operation_xml,
        signature     => $signature,
    );
}

sub CnB_reply
{
    my %p = @_;
    my $sxml = XML::Simple->new() or return( error=>'xml making error' );
    my($xml, $result); 
    eval {
        $xml = decode_base64( $p{operation_xml} );
        $result = $sxml->XMLin( $xml );
    };
    if( $@ )
    {
        debug('error', "$@");
        return( error=>'xml error' );
    }
    debug('pre', $result);

    if( _signature($xml) ne $p{signature} )
    {
        debug('warn', {calc_sign=>_signature($xml), recv_sign=>$p{signature}} );
        return( error=>'signature error' );
    }
    return( result=>$result );
}


sub API
{
    my %p = @_;

    eval "use LWP::UserAgent; use HTTP::Request::Common;";

    my $sxml = XML::Simple->new() or return( error=>'xml making error' );
    $p{version} = '1.2';
    my $request = { map{ $_ => [$p{$_}] } keys %p };

    my $xml = $sxml->XMLout( $request, RootName=>'request' );
    debug('pre', $xml);

    # Для опасных операций у мерчанта другая подпись
    my $liq_sign = $p{action} =~ /^(send_money|phone_credit)$/? $cfg::liqpay_merch_risky_sign : '';
    
    my $signature     = _signature($xml, $liq_sign); 
    my $operation_xml = encode_base64($xml);
    chomp $operation_xml;
    
    my $request = {
        operation_xml  => [$operation_xml],
        signature      => [$signature],
    };
    my $xml = $sxml->XMLout( $request, RootName=>'operation_envelope' );
    $xml = '<?xml version=\"1.0\" encoding=\"UTF-8\"?>'.
        '<request><liqpay>'.$xml.'</liqpay></request>';

    debug("На $cfg::liqpay_api_url отсылаем:", $xml);

    my $userAgent = LWP::UserAgent->new( agent=>'NodenyAgent' );
    my $response = $userAgent->post( $cfg::liqpay_api_url, Content_Type=>'text/xml', Content=>$xml );

    if( !$response->is_success )
    {
        debug('pre', 'Статус:', $response->status_line );
        return( error=>'Liqpay connection error' );
    }

    my $raw_xml = $response->content;
    eval {
        $xml = $sxml->XMLin( $raw_xml );
    };
    if( $@ )
    {
        my $err = "Ошибка парсинга xml: $@";
        debug('pre', 'Получили от Liqpay:', $raw_xml);
        debug('error', $err);
        return( error=>'Liqpay xml error' );
    }
    if( ref $xml ne 'HASH' || 
        ref $xml->{liqpay} ne 'HASH' || 
        ref $xml->{liqpay}{operation_envelope} ne 'HASH' ||
        ! $xml->{liqpay}{operation_envelope}{operation_xml} ||
        ! $xml->{liqpay}{operation_envelope}{signature}
    ){
        debug('pre', 'Получили от Liqpay:', $raw_xml);
        debug('error', 'pre', 'Ошибка в структуре xml', $xml);
        return( error=>'Ошибка в структуре xml' );
    }
    my $oxml = decode_base64( $xml->{liqpay}{operation_envelope}{operation_xml} );
    debug('pre', "decode_base64( operation_xml ):\n", $oxml);

    my $recv_signature = $xml->{liqpay}{operation_envelope}{signature};
    my $calc_signature = _signature($oxml, $liq_sign);
    if( $calc_signature ne $recv_signature )
    {
        debug('warn', {calc_sign=>$calc_signature, recv_sig=>$recv_signature} );
        return( error=>'signature error' );
    }

    debug('signature ok');

    eval {
       $xml = $sxml->XMLin( $oxml );
    };
    if( $@ )
    {
        debug('error', "$@");
        Error('Liqpay operation_xml error');
    }

    return( result=>$xml );
}


sub _signature
{
    my($xml, $liq_sign) = @_;
    $liq_sign ||= $cfg::liqpay_merch_sign;
    my $signature = encode_base64( sha1($liq_sign.$xml.$liq_sign) ); 
    chomp $signature;
    return $signature;
}

1;
