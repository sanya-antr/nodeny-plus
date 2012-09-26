#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel::system_check;
use strict;
use Debug;
use Db;
use nod::tasks;

our @ISA = qw{kernel};

sub start
{
    my(undef, $single, $param) = @_;

    nod::tasks->new(
        task         => \&main,
        period       => $param->{period} || 60*60,
        first_period => $single? 0 : 40,
    );
}

my @Check = (
    {
        sub      => sub {
            my $st_table = Db->dbh->column_info(undef, undef, 'data0', undef);
            my %cols = ();
            while( my $table_hash = $st_table->fetchrow_hashref() )
            {
                $cols{$table_hash->{COLUMN_NAME}} = 1;
            }
            my $db = Db->sql("SELECT name FROM datasetup UNION SELECT 'id' UNION SELECT 'uid'");
            $db->ok or return(0, '');
            while( my %p = $db->line )
            {
                if( $cols{$p{name}} )
                {
                    delete $cols{$p{name}};
                    next;
                }
                return(5, "В таблице data0 не существует поля `$p{name}`");
            }
            foreach my $name( keys %cols )
            {
                return(2, "В таблице data0 существует поле `$name`, которое не описано в datasetup");
            }
            return(0, '');
        },
    },
    {
        sql      => 'SELECT u.name FROM users u WHERE EXISTS (SELECT * FROM admin WHERE login=u.name)',
        err_expr => 'Db->rows > 0 && 5',
        err_msg  => 'Есть совпадения логинов клиентов и админов',
        
    },
    {
        sql      => 'SELECT u.id FROM users u WHERE NOT EXISTS (SELECT * FROM user_grp WHERE grp_id=u.grp)',
        err_expr => 'Db->rows > 0 && 2',
        err_msg  => 'Есть клиенты в несуществующих группах',
    },
    {
        sql      => 'SELECT u.id FROM users u WHERE NOT EXISTS (SELECT * FROM data0 WHERE uid=u.id)',
        err_expr => '$db->rows > 0 && 2',
        err_msg  => 'Есть клиенты, у которых нет записи в таблице дополнительных данных (data0)',
    },
    {
        sql      => 'SELECT p.id FROM pays p WHERE p.mid>0 AND NOT EXISTS (SELECT * FROM users WHERE id=p.mid)',
        err_expr => 'Db->rows > 0 && 1',
        err_msg  => 'Есть платежи несуществующих клиентов',
    },
    {
        sql      => 'SELECT * FROM data0 d WHERE NOT EXISTS (SELECT * FROM users WHERE id=d.uid)',
        err_expr => 'Db->rows > 0 && 1',
        err_msg  => 'В дополнительных данных есть привязанные к несуществующему клиенту',
    },
    {
        sql      => 'SELECT * FROM users_trf t WHERE NOT EXISTS (SELECT * FROM users WHERE id=t.uid)',
        err_expr => 'Db->rows > 0 && 1',
        err_msg  => 'В таблице трафика есть данные, привязанные к несуществующему клиентуе',
    },
    {
        sql      => 'SELECT * FROM users_services s WHERE NOT EXISTS (SELECT * FROM users WHERE id=s.uid)',
        err_expr => 'Db->rows > 0 && 1',
        err_msg  => 'В таблице услуг есть данные, привязанные к несуществующему клиенту',
    },
    {
        sql      => 'SELECT * FROM users_services s WHERE NOT EXISTS (SELECT * FROM services WHERE service_id=s.service_id)',
        err_expr => 'Db->rows > 0 && 3',
        err_msg  => 'В таблице услуг есть ссылки на несуществующие услуги',
    },
    {
        sql      => 'SELECT * FROM users_services WHERE tm_end>0 AND tm_end<(UNIX_TIMESTAMP()-24*3600)',
        err_expr => 'Db->rows > 0 && 3',
        err_msg  => 'Есть услуги, которые должны были быть завершены больше суток назад',
    },
    {
        sql      => 'SELECT * FROM ip_pool i WHERE i.uid>0 AND NOT EXISTS (SELECT * FROM users WHERE id=i.uid)',
        err_expr => 'Db->rows > 0 && 1',
        err_msg  => 'В таблице ip_pool есть данные, привязанные к несуществующему клиенту',
    },
    {
        sql      => 'SELECT u.id, u.balance, SUM(p.cash) AS chk_balance FROM users u LEFT JOIN pays p ON u.id=p.mid GROUP BY u.id HAVING u.balance<>chk_balance',
        err_expr => 'Db->rows > 0 && 3',
        err_msg  => 'Есть расхождения суммы платежей и баланса клиента',
    },
    {
        sub      => sub {
            my $db = Db->sql('SELECT service_id,param FROM services');
            $db->ok or return(0, '');
            my $VAR1;
            while( my %p = $db->line )
            {
                eval $p{param};
                $@ or next;
                debug('warn', "$@");
                return(5, "Ошибка декодирования поля param услуги service_id=$p{service_id}");
            }
            return(0, '');
        }
    },
);

sub main
{
    my %errors = map{ $_ => 0 }(1..5);
    my $errors = 0;
  {
    local $SIG{'__DIE__'} = {};
    foreach my $p( @Check )
    {
        my($err_lvl, $err_msg);
        if( $p->{sql} )
        {
            my %p = Db->line($p->{sql});
            Db->ok or next;
            $err_lvl = eval $p->{err_expr};
            if( $err_lvl )
            {
                $err_msg = $p->{err_msg} || 'Зафиксирована ошибка: '.$p->{sql};
            }
        }
        if( $p->{sub} )
        {
            ($err_lvl, $err_msg) = &{$p->{sub}};
            $@ && debug('warn', "$@");
        }
        if( $err_lvl )
        {
            $errors{ $err_lvl }++;
            tolog($err_msg.'. Важность проблемы: '.$err_lvl);
            $errors++;
        }
    }
  }
    $errors or return;
    Db->do('INSERT INTO pays SET category=250, time=UNIX_TIMESTAMP(), reason=?', Debug->dump(\%errors));
}

1;