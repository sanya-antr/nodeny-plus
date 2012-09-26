#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# Агент L2 авторизации
# ---------------------------------------------
package kernel::authserver;
use strict;
use Time::localtime;
use Crypt::Rijndael;
use IO::Socket;
use Debug;
use Db;
use nod::tasks;

our @ISA = qw{kernel};

my $M;

sub start
{
    my(undef, $single, $param) = @_;
    $M = $param;
    bless $M;

    $M->{users} = {};
    $M->{db_errors} = 0;

    $M->{bind_ip} = $M->{bind_ip}? inet_aton($M->{bind_ip}) : INADDR_ANY;
    $M->{bind_port} ||= 7723;

    my $proto = getprotobyname('udp');
    socket( SOCKET, PF_INET, SOCK_DGRAM, $proto ) or die 'Socket create error';
    bind( SOCKET, sockaddr_in($M->{bind_port}, $M->{bind_ip}) ) or die "Can't bind to port $M->{bind_port}!";

    $M->{load_user_min_period} = int $M->{load_user_min_period} || 25;

    nod::tasks->new(
        task         => \&get_connections,
        period       => 0,
        first_period => $single? 0 : 2,
    );
}


# --- Обработка соединений ---

sub get_connections
{
    my $rin = '';
    vec($rin, fileno(SOCKET), 1) = 1;
    while( select(my $pkt=$rin,undef,undef,0) )
    {
        $pkt = '';
        # игнорируем все, что в пакетах за 100м байтом
        my $hispaddr = recv(SOCKET,$pkt,100,0);
        my($usr_port,$usr_addr) = sockaddr_in($hispaddr);
        my $usr_ip = join '.', unpack('C4',$usr_addr);

        if( $cfg::verbose )
        {
            my $hex_pkt  = $pkt;
            $hex_pkt =~ s/(.)/sprintf("%x",ord($1))/eg;
            debug("Пакет от $usr_ip в HEX:", $hex_pkt);
        }

        if( $M->{db_errors} > 3 )
        {
            if( ! nod::tasks->protect_time(60, 'db_errors') )
            {
                debug($M->{db_errors}, 'ошибок БД, некоторое время не делаем запросы в БД');
                next;
            }
            Db->disconnect;
            $M->{db_errors} = 0;
        }

        my $usr = $M->get_usr_info($usr_ip);

        if( ! $usr->{id} )
        {   # в БД нет инфы по клиенту либо ошибка соединения с БД,
            # ничего не отвечаем и клиент переключится на резервный сервер
            debug("Неизвестный ip $usr_ip");
            next;
        }

        $usr->{pkt} = $pkt;
        # формируем адрес для ответа (это новое соединение!)
        my $send_adr = inet_aton($usr_ip);
        $usr->{send_adr} = sockaddr_in($M->{bind_port}, $send_adr);

        # Получили запрос на формирование случайной строки?
        if( length($pkt)<16 )
        {
            $M->auth_step_1($usr);
            next;
        }

        $M->auth_step_2($usr);
    }
}

sub auth_step_1
{
    my($M, $usr) = @_;
    my $id_query = $usr->{pkt};

    # Сформируем случайный ключ авторизации
    my $auth_key = substr( rand().rand().'errorinlastline', 2, 16 );
    # id должен содержать случайные символы, а у нас только цифры, поэтому зашифруем
    $auth_key = new Crypt::Rijndael $auth_key , Crypt::Rijndael::MODE_CBC;
    $auth_key = $auth_key->encrypt( substr(rand().rand().'qazxswedcvfrtgbn',2,16) );
    # разделитель `запятая` может встретится в ключе, меняем на другой символ
    $auth_key =~ s/,/-/g;

    $usr->{auth_key} = $auth_key;
    $usr->{id_query} = $id_query;

    my $send = new Crypt::Rijndael $usr->{passwd2}, Crypt::Rijndael::MODE_CBC;
    # зашифруем случайную строку исходящим паролем
    $send = 'id'.($send->encrypt($auth_key)).$id_query;

    if( $cfg::verbose )
    {
        my $hex_key  = $auth_key;
        $hex_key =~ s/(.)/sprintf("%x",ord($1))/eg;
        my $hex_send  = $send;
        $hex_send =~ s/(.)/sprintf("%x",ord($1))/eg;
        debug('Шаг 1: старт авторизации', {
            '1) id авторизации' => $id_query,
            '2) сгенерирован ключ авторизации' => $hex_key,
            '3) зашифрован и отослан пакет с ключем' => $hex_send,
        });
    }
    send(SOCKET, $send , 0, $usr->{send_adr});
}

sub auth_step_2
{
    my($M, $usr) = @_;
    my $auth_key = $usr->{auth_key};
    my $pkt = $usr->{pkt};

    if( ! $auth_key )
    {
        debug("Запроса на авторизацию не было. Игнорируем");
        next;
    }

    # версия авторизатора
    my $ver = int(substr $usr->{id_query}, 0, 2);
    $ver = 1 if $ver<1 || $ver>255;


    my $ClientAnswer = ''; # ответ клиента на дополнительные команды заказанные сервером
    # выделим команду
    my $orig_cmd = substr $pkt,16,1;
    my $cmd = lc $orig_cmd;
    # id сессии
    my $id = length($pkt)<18 ? '' : substr $pkt,17,length($pkt)-17;
    ($id, $ClientAnswer) = ($1,$2) if $id =~ /^(.+?)\|(.+)$/;

    if( $id ne $usr->{id_query} )
    {
        debug("id сессии не соответствует текущей. Игнорируем");
        next;
    }

    # больше по этому ключу авторизоваться будет нельзя
    $usr->{auth_key} = '';

    my $cipher = new Crypt::Rijndael $usr->{passwd1}, Crypt::Rijndael::MODE_CBC;
    my $auth_key_from_usr = $cipher->decrypt(substr $pkt,0,16);
    if( $auth_key_from_usr ne $auth_key )
    {
        debug("Несовпадение ключей. Авторизация неуспешна");
        send(SOCKET, 'no'.$usr->{id_query}, 0, $usr->{send_adr});
        return;
    }

    debug('Авторизация успешна');

    # здесь $cmd =
    # a - запрос на включение полного доступа
    # b - запрос на блокирование доступа
    # c - запрос на включение полного доступа (ранее доступа к сетям 2 направления)
    # e - запрос на включение полного доступа с просьбой разрешить пингование

    my $send;
    my $str;
    # Если клиент передал запрос в верхнем регистре - значит он запросил команду у сервера
    # (в новых авторизаторах всегда первая сессия авторизации)
    if( $cmd ne $orig_cmd )
    {
        $send = 'go';
        $str = $usr->{id_query}.'|';
        $str .= ' ' x 16;
    }
     else
    {     
        # $cod - пересылаемое состояние авторизатору
        # 5 - если доступ закрыт
        my $cod = $usr->{state} eq 'off'? 5 : $cmd;
        my $mess_time = 0;
        # `sv` разрешает закладку `админ` в авторизаторе
        $send = $usr->{admin}? 'sv' : 'ok';

        $str = "$usr->{id_query},$cod,0,$usr->{traf1},$usr->{traf2},$usr->{traf3},$usr->{traf4},0,$usr->{balance},$mess_time";
        map{ $str .= ",$_" }( 1..4 );
        $str .= ',.'.' ' x 15;
        debug("Незакодированный ответ:", $str);
    }

    my $cipher = new Crypt::Rijndael $auth_key, Crypt::Rijndael::MODE_CBC;
    while( length($str)>15 )
    {
       $send .= $cipher->encrypt(substr $str,0,16);
       $str = substr $str,16,length($str)-16;
    }
    send(SOCKET, $send, 0, $usr->{send_adr});

    Db->do("CALL set_auth(?,?)", $usr->{ip}, 'mod=noauth');
}

sub get_usr_info
{
    my($M, $ip) = @_;
    $M->{users}{$ip} ||= {};
    my $usr = $M->{users}{$ip};

    nod::tasks->protect_time($M->{load_user_min_period}, 'usr_info', $ip) or return $usr;

    my %u = Db->line(
        "SELECT f.id, f.state, f.traf1, f.traf2, f.traf3, f.traf4, f.balance, ".
            "INET_NTOA(i.ip) AS ip, AES_DECRYPT(passwd,?) AS pass ".
            "FROM ip_pool i JOIN fullusers f ON i.uid = f.id WHERE INET_NTOA(i.ip) = ?",
        $cfg::Passwd_Key, $ip
    );
    if( !%u )
    {   # данные не получены, если ошибка БД - вернем устаревшие, если нет записи - обнулим данные
        if( Db->ok )
        {
            $usr = {};
        }
         else
        {
            $M->{db_errors}++;
        }
        return $usr;
    }

    $u{passwd2} = substr( substr($u{pass},0,3).'Z' x 16,0,16 );
    $u{passwd1} = substr( $u{pass}.'0' x 19,3,16 );

    map{ $usr->{$_} = $u{$_} } keys %u;

    return $usr;
}

1;