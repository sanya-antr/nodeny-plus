#!/usr/bin/perl
=head INFO
my $httpd = nod::httpd->new( port => 8080 );
$httpd->{response}{headers}{'Content-Type'} = 'text/html; charset=windows-1251';

# Url каждого принятого http-запроса проверяется на условия в адресной строке
# Условия обрабатываются сверху вниз
$httpd->set_conditions(
    { condition => { a => 'ok', b => 1 }, sub => \&test1, },  #  test1() вызвается при http://xxx.xx/xx?xx&a=ok&b=1xxx
    { condition => {},                    sub => \&test2, },  #  test2() вызвается при любом url
);

$httpd->run();

while( <> ) {}

sub test1
{
    my($con) = @_;
    $con->send('В адресной строке a=ok и b=1');
}

sub test2
{
    my($con) = @_;
    $con->send("Ваш ip $con->{ip}");
}

=cut

package nod::httpd;
use strict;
use IO::Socket;
use IO::Select;
use threads;
use threads::shared;

use Debug;

Debug->threaded;

my $defaults = {
    port        => 8000,
    listen      => 200,
    response    => {
        ok      => 'HTTP/1.1 200 OK',
        headers => {
                'Cache-Control' => 'no-store',
                'Pragma'        => 'no-cache',
                'Content-Type'  => 'text/html; charset=utf-8',
        }
    },
    sock2con    => {},
    con2sock    => {},
    conditions  => [],
};

sub new
{
    my($cls, %param) = @_;
    my $httpd = { %$defaults };
    map{ $httpd->{$_} = $param{$_} } keys %param;
    bless $httpd;
    return $httpd;
}

sub set_conditions
{
    my($httpd, @conditions) = @_;
    ref $httpd or return;
    $httpd->{conditions} = \@conditions;
}

sub run
{
    my($httpd) = @_;
    if( ! ref $httpd )
    {
        $httpd = $httpd->new();
    }
    $httpd->{sock} = IO::Socket::INET->new(
        LocalPort   => $httpd->{port},
        Listen      => $httpd->{listen},
        Proto       => 'tcp',
        Reuse       => 1,
    );
    $httpd->{sock} or die 'Ошибка создания сокета!';
    debug("Слушаем порт $httpd->{port}");

    $httpd->{select} = IO::Select->new();
    $httpd->{select} or die 'Ошибка создания объекта IO::Select!';

    $httpd->{select}->add($httpd->{sock});

    threads->create( \&_listen, $httpd );
    return $httpd;
}

sub new_connection
{
    my($httpd) = @_;
    my($sock, $con);
    eval {
        $sock = $httpd->{sock}->accept() or die;
        $con = nod::connection->new($httpd, $sock);
        $httpd->{select}->add($sock);
        $sock->autoflush(1);
    };
    if( $@ )
    {
        $httpd->close_socket($sock);
        return;
    }
    $httpd->{sock2con}{$sock} = $con;
    $httpd->{con2sock}{$con} = $sock;
}

sub get_connection
{
    my($httpd, $sock) = @_;
    return $httpd->{sock2con}{$sock};
}

sub close_socket
{
    my($httpd, $sock) = @_;
    $sock or return;
    eval{ 
        $httpd->{select}->exists($sock) && $httpd->{select}->remove($sock);
    };
    eval{ close $sock };
}

sub close_connection
{
    my($httpd, $con)= @_;
    my $sock = $httpd->{con2sock}{$con};
    delete $httpd->{con2sock}{$con};
    if( $sock )
    {
        delete $httpd->{sock2con}{$sock};
        $httpd->close_socket($sock);
    }
}

sub _listen
{
    my($httpd) = @_;

    threads->detach();

    $SIG{'INT'} = sub
    {
        foreach my $con( %{$httpd->{con2sock}} )
        {
            $httpd->close_connection($con);
        }
        threads->exit();
    };
    while( 1 )
    {
        my @ready = $httpd->{select}->can_read(0);
        foreach my $sock( @ready )
        {

            # новое соединение?
            if( $sock eq $httpd->{sock} )
            {
                $httpd->new_connection();
                next;
            }

            my $con;
            eval
            {
                $con = $httpd->get_connection($sock);
                if( !$con )
                {
                    $httpd->close_socket($sock);
                    next;
                }

                my $pkt = $con->recv(1024);

                if( ! length $pkt )
                {
                    $httpd->close_connection($con);
                    next;
                }

                $pkt = $con->input();
                if( $pkt !~ /\r\n\r\n/ )
                {
                    chomp $pkt;
                    $con->debug('Получен не полный http-запрос (нет двух переводов строк), все ок - накапливаем: ', $pkt);
                    if( length $pkt > 4096 )
                    {
                        $con->debug('Слишком большой http заголовок. Соединение закрываем');
                        $httpd->close_connection($con);
                    }
                    next;
                }

                # в случае get-запроса $body будет undef
                $con->debug('!',$pkt);
                my($header, $body) = split /\r\n\r\n/, $pkt, 2;
                if( $header !~ s/^(GET|POST)\s+([^\s]+)[^\n]+\n//i )
                {
                    $con->debug("Заголовок не похож на POST/GET http-запрос:\n", $header);
                    $httpd->close_connection($con);
                    next;
                }
                my($method, $url) = ($1, $2);

                $con->{header} = {};
                foreach( split /\r\n/, $header )
                {
                    my($k, $v) = split /:\s*/, $_, 2;
                    $con->{header}{lc $k} = $v;
                }
                # разделим на uri и запрос
                my($uri, $query) = split /\?/, $url, 2;
                $query ||= '';

                $con->{header}{url} = $url;
                $con->{header}{uri} = $uri;
                $con->{header}{query} = $query;

                $con->debug('Header:', $con->{header});

                if( lc($method) eq 'post' && $con->{header}{'content-length'} > 0 )
                {
                    my $len = $con->{header}{'content-length'};
                    if( length($body) < $len )
                    {
                        $con->debug("Размер Post-запроса $len байт, но пока получено только ".length($body).". Ждем остаток...");
                        next;
                    }
                    $query .= '&' if $query ne '';
                    $query .= $body;
                }

                foreach my $pair( split /&/,$query )
                {
                    my($name,$value) = split /=/,$pair;
                    $name =~ tr/+/ /;
                    $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
                    $value=~ tr/+/ /;
                    $value=~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
                    $con->{query}{$name} = $value;
                }

                $con->debug('Query:', keys %{$con->{query}}? $con->{query} : 'empty');

                foreach my $p( @{ $httpd->{conditions}} )
                {
                    ref $p eq 'HASH' or next;
                    my $hit = 1;
                    foreach my $condition( keys %{ $p->{condition} } )
                    {
                        $con->{query}{$condition} eq $p->{condition}{$condition} && next;
                        $hit = 0;
                    }
                    if( $hit )
                    {
                        &{ $p->{sub} }($con);
                        last;
                    }
                }

            }; # -- end eval --
            $@ && debug("$@");

            $httpd->close_connection($con);
        }

        select(undef,undef,undef,0.01);
    }
}

package nod::connection;
use IO::Socket;
use Debug;

sub new
{
    my($cls, $parent, $sock) = @_;
    my($port, $addr) = sockaddr_in($sock->peername);
    my $con = bless {
        parent  => $parent,
        sock    => $sock,
        ip      => join('.', unpack('C4',$addr)),
        port    => $port,
        input   => '',
        query   => {},
        header  => {},
        response => {
            ok      => $parent->{response}{ok},
            headers => { %{$parent->{response}{headers}} },
        },
    };
    return $con;
}

sub debug
{
    my($con, @msg) = @_;
    Debug->add("[$con->{ip}:$con->{port}]", @msg);
}

sub recv
{
    my($con, $bytes) = @_;
    my $sock = $con->{sock} || return '';
    my $pkt;
    sysread($sock, $pkt, $bytes);
    $con->{input} .= $pkt;
    return $pkt;
}

sub input
{
    my($con) = @_;
    return $con->{input};
}

sub send
{
    my($con, $pkt) = @_;
    utf8::is_utf8($pkt) && utf8::encode($pkt);
    my $sock = $con->{sock} or return;
    my $header = join "\r\n",
        $con->{response}{ok},
        (map{ "$_:$con->{response}{headers}{$_}"} keys %{$con->{response}{headers}}),
        'Content-Length:'.(length($pkt)-10)."\r\n\r\n"
    ;
    $con->debug('Отправляем:',$header.$pkt);
    eval{
        $sock->send($header.$pkt);
    };
    if( $@ )
    {
        my $err = $@;
        chomp $err;
        $con->debug("Ошибка отправки ($err), вероятно клиент разорвал соединение.");
    }
}

