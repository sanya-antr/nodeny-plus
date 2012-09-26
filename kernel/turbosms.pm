#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::turbosms;
use strict;
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

    nod::tasks->new(
        task         => \&main,
        period       => 3600,
        first_period => $single? 0 : 50,
    );
}

sub main
{
    my $phone_extract_sub = $M->{phone_extract};

    my $sms_sign = $cfg::turbosms_sign;
    
    my $db_table = $cfg::turbosms_db_login;
    $db_table =~ /['\\]/ && die 'check db_login';

    my $sms_db = Db->new(
        host    => $cfg::turbosms_db_server,
        user    => $cfg::turbosms_db_login,
        pass    => $cfg::turbosms_db_pass,
        db      => $cfg::turbosms_db_database,
        timeout => 3,
        tries   => 2,
        global  => 0,
    );

    $sms_db->connect;

    if( ! $sms_db->is_connected )
    {
        tolog('Error. Cannot connect to sms DB');
        return;
    }

    my $db = Db->sql(
        "SELECT v.id, v.uid, s.price, u.balance, d._adr_telefon, FROM_UNIXTIME(v.tm_end) AS date ".
            "FROM users_services v ".
            "JOIN users u ON v.uid=u.id ".
            "JOIN services s ON v.next_service_id=s.service_id ".
            "JOIN data0 d ON v.uid=d.uid ".
        "WHERE v.tm_end>0 ".                        # услуга имеет срок действия,
            "AND v.tm_end<(UNIX_TIMESTAMP()+?) ".   # скоро заканчивается,
            "AND v.next_service_id>0 ".             # установлена следующая,
            "AND s.price>0 ".                       # ее стоимость > 0 (т.е не бонус, а снятие),
            "AND u.balance<s.price ".               # баланс меньше стоимости следующей услуги,
            "AND block_if_limit>0 ".                # включена блокировка при балансе ниже лимита,
            "AND u.state='on' ".                    # в данный момент доступ включен,
            "AND d._adr_telefon<>'' ".              # у клиента есть телефон,
            "AND v.tags NOT LIKE '%,expire_sms,%' ".# нет тега expire_sms (означает, что sms уже отсылалось)
           "AND NOT EXISTS (SELECT id FROM v_services WHERE uid=u.id AND price<0)", # не подключена бонусная услуга
        4*24*3600
    );
    while( my %p = $db->line )
    {
        my $phone = &{$phone_extract_sub}($p{_adr_telefon}) || next;
        # Запятые тега с обоих сторон на случай, если текущее поле tags пустое - будет работать LIKE '%,expire_sms,%',
        # а если текущий tags не пустой, то 2 запятых подряд ничего страшного
        my $rows = Db->do("UPDATE users_services SET tags=CONCAT(tags,',expire_sms,') WHERE id=?", $p{id});
        $rows>0 or next;

        my $message = $M->{sms};
        $message =~ s/\{\{date\}\}/$p{date}/;
        $sms_db->do(
            "INSERT INTO $db_table SET number=?, sign=?, message=?, send_time=NOW()",
            $phone, $sms_sign, $message
        );
    }
}

1;