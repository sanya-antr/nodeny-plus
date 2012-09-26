#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package services;
use strict;
use Debug;
use Db;

=head

--- proc ---

 Параметр cmd:

    add         : подключение услуги
                    uid         : user id
                    service_id  : id услуги

    set_next    : в подключенной услуге устанавливает поле `следующая услуга`
                    uid         : user id
                    service_id  : id `следующей услуги`
                    id          : id существующей услуги по таблице user_services

    end         : завершение услуги
                    uid         : user id
                    id          : id существующей услуги по таблице user_services

    next        : завершение услуги и подключение новой из поля `следующая услуга`
                    uid         : user id
                    id          : id существующей услуги по таблице user_services

    Избыточные условия в sql для защиты

    При add/set_next, если creator->{type} = 'user', то проверяется:
        - имеет ли группа клиента доступ к услуге
        - `следующая` услуга в том же модуле, что и текущая

 Возврат: 0 - все ок, иначе ссылка на хеш:
        {
            for_adm => 'сообщение для администратора',
            for_usr => 'сообщение для клиента',
        };

=cut

my %cmd = (
    add      => 'Подключение услуги',
    set_next => 'Установка поля следующей услуги',
    end      => 'Завершение услуги',
    next     => 'Завершение услуги с подключением следующей',
);

sub proc
{
    my(undef, %param) = @_;
    my $cmd         =     $param{cmd};
    my $id          = int $param{id};
    my $uid         = int $param{uid};
    my $service_id  = int $param{service_id};
    my $creator     =     $param{creator};
    my $actions     =     $param{actions} || {};

    my $return_err_hash = {
        for_adm => 'временная ошибка',
        for_usr => 'временная ошибка',
    };

    if( !$cmd{$cmd} )
    {
        debug('error', 'Не задан или не верен параметр cmd');
        return {
            for_adm => 'внутренняя ошибка: не задан или не верен параметр cmd',
            for_usr => '',
        };
    }

    debug($cmd{$cmd});

    # Параметры услуги, которая завершается
    my %service_old = ();

    # --- Завершение текущей услуги / завершение с установкой новой из поля next_service_id ---

    {
        ($cmd eq 'end' || $cmd eq 'next') or last;

        %service_old = Db->line("SELECT *, UNIX_TIMESTAMP() AS t FROM v_services WHERE id=? AND uid=? LIMIT 1", $id, $uid);
        %service_old or return {
            for_adm => 'услуга с заданным id не найдена либо привязана другому клиенту',
            for_usr => '',
        };

        $actions->{sql}{_remove_old_service} = [
            "DELETE FROM users_services WHERE id=? AND uid=? LIMIT 1", $id, $uid
        ];

        # --- Завершение услуги раньше времени ее окончания - уменьшим сумму платежа ---
        {
            $service_old{tm_end} > ($service_old{t}+5) or last;

            debug('Досрочное завершение услуги');

            my $pay_id = $service_old{pay_id} or last;
            my $t = $service_old{t};
            my $tm_start = $service_old{tm_start};
            my $tm_end = $service_old{tm_end};
            $t > $tm_start or last; # перестраховка от искажения данных, также избежим деления на 0
            my %pay = Db->line("SELECT cash, mid FROM pays WHERE id=?", $pay_id);
            if( !%pay )
            {
                Db->ok && last; # платеж не существует, возможно удален администратором
                return $return_err_hash;
            }
            # если нестыковка и платеж принадлежит другому клиенту - не меняем
            $pay{mid} == $uid or last;
            my $old_cash = $pay{cash};
            abs($old_cash) < 0.01 && last;
            # Сколько % времени использовалась услуга
            my $k = sprintf "%.4f", ($t-$tm_start) / ($tm_end-$tm_start);
            if( $k == 1 )
            {
                debug('Услуга использовалась практически 100.00% времени, поэтому сумму платежа не меняем');
                last;
            }
            # Несмотря на то, что дальше будет проверка суммы, клиент должен видеть, что он пользовался не 0%, а 0.01% времени
            $k = 0.0001 if $k<0.0001;
            my $new_cash = sprintf "%.2f", $k * $old_cash;
            if( abs($new_cash) < 0.01 )
            {
                $new_cash = $old_cash>0? 0.01 : -0.01;
            }
            $actions->{sql}{_reduce_the_price} = [
                "UPDATE pays SET cash=?, comment=CONCAT(comment,'\nДосрочное завершение, использовано ',?,'% услуги') ".
                    "WHERE id=? AND mid=? AND ABS(cash-(?))<0.01 LIMIT 1",
                    $new_cash, $k*100, $pay_id, $uid, $old_cash,
            ];
            $actions->{sql}{_reduce_balance} = [
                "UPDATE users SET balance = balance-(?)+? WHERE id=? LIMIT 1", $old_cash, $new_cash, $uid
            ];
        }
        $cmd eq 'next' or last;

        $service_id = $service_old{next_service_id};

        $cmd = $service_id? 'add' : 'end';
    }


    # --- Подключение услуги / установка поля `следующая услуга`

    {
        ($cmd eq 'add' || $cmd eq 'set_next') or last;

        my %service_new = (); # параметры услуги, которая будет установлена
        if( $service_id )
        {
            %service_new = Db->line("SELECT * FROM services WHERE service_id=? LIMIT 1", $service_id);
            Db->ok or return {
                for_adm => 'временная ошибка',
                for_usr => 'временная ошибка',
            };
            if( !%service_new )
            {
                debug('error', "Услуга с service_id = $service_id не найдена в таблице services");
                return {
                    for_adm => 'услуга с заданным service_id не существует',
                    for_usr => '',
                };
            }

            my %u = Db->line("SELECT grp, discount FROM users WHERE id=? LIMIT 1", $uid);
            %u or return {
                for_adm => 'ошибка получения данных клиента',
                for_usr => '',
            };;
            if( $creator->{type} eq 'user' )
            {
                if( $service_new{grp_list} !~ /,$u{grp},/ )
                {
                    debug('error', "Услуга с service_id = $service_id не разрешена клиенту в группе $u{grp}");
                    return {
                        for_adm => 'услуга не разрешена клиенту',
                        for_usr => 'вам недоступна запрошенная услуга',
                    };
                }
                if( $cmd eq 'set_next' && $service_old{module} ne $service_new{module} )
                {
                    debug('error', 'Клиенту не разрешено продлевать услугу услугой из другого модуля');
                    return {
                        for_adm => '',
                        for_usr => '',
                    };
                }
                if( $cmd eq 'add' )
                {
                    my %tmp = Db->line(
                        "SELECT 1 FROM v_services WHERE uid=? AND module=? LIMIT 1",
                        $uid, $service_new{module},
                    );
                    Db->ok or return {
                        for_adm => 'временная ошибка',
                        for_usr => 'временная ошибка',
                    };
                    if( %tmp )
                    {
                        debug('error', 'Клиенту не разрешено подключать услугу модуля уже подключенной услуги');
                        Db->ok or return {
                            for_adm => 'Клиенту не разрешено подключать услугу модуля уже подключенной услуги',
                            for_usr => 'у вас уже подключена аналогичная услуга',
                        };
                    }
                }
            }
            $service_new{discount} = $u{discount};

            # Если по умолчанию услуга автопродлеваемая - установим поле `следующая услуга`
            if( $service_new{auto_renew} )
            {
                $actions->{_set_next_service_id} = $service_id;
            }
        }

        # --- Установка поля `следующая услуга`

        if( $cmd eq 'set_next' )
        {
            $actions->{sql}{_set_next_service_id} = [
                "UPDATE users_services SET next_service_id=? WHERE id=? AND uid=? LIMIT 1", $service_id, $id, $uid
            ];
            last;
        }

        # --- Подключение услуги

        $service_id or last;

        my $crit_err = {
            for_adm => 'параметры услуги повреждены',
            for_usr => 'данная услуга временно недоступна',
        };

        {
            local $SIG{'__DIE__'} = {};
            my $VAR1;
            eval $service_new{param};
            if( $@ )
            {
                debug('error', "Параметры услуги повреждены: $@");
                return $crit_err;
            }
            $service_new{param} = $VAR1;
        }

        my $pkg = "services::$service_new{module}";

        eval "use $pkg";
        if( $@ )
        {
            debug('error', "use $pkg: $@");
            return $crit_err;
        }

        $pkg->set_service(
            actions     => $actions,
            uid         => $uid,
            service_new => \%service_new,
            service_old => \%service_old,
        );

        if( $@ )
        {
            debug('error', "$pkg set_service: $@");
            return $crit_err;
        }

    }



    # --- Обработка действий в $actions ---


    # Модуль услуги сообщает об ошибке
    ref $actions->{error} && return $actions->{error};

    TRANSACTION : 
    {

        if( !Db->begin_work )
        {
            debug('error', 'Db->begin_work fail');
            last;
        }

        if( ref $actions->{sql} )
        {
            foreach my $sql( keys %{$actions->{sql}} )
            {
                Db->do( @{$actions->{sql}{$sql}} ) > 0 or last TRANSACTION;
            }
            $return_err_hash = '';
        }

        if( $actions->{set_service} )
        {
            my $p = $actions->{set_service};
            if( ref $p ne 'HASH' )
            {
                debug('error', 'Действие set_service не является ссылкой на хеш');
                last;
            }

            $p->{tm_start} ||= time();

            # tm1 и tm2: начало и конец месяца для времени старта
            my $sql = 'SELECT UNIX_TIMESTAMP(LAST_DAY(FROM_UNIXTIME(?) - INTERVAL 1 MONTH) + INTERVAL 1 DAY) AS tm1, '.
                'UNIX_TIMESTAMP(LAST_DAY(FROM_UNIXTIME(?)) + INTERVAL 1 DAY) AS tm2';
            my @sql_param = ($p->{tm_start}, $p->{tm_start});

            if( $p->{mode} == 1 )
            {   # Срок действия месяц (разное количество дней в месяце)
                $sql .= ', UNIX_TIMESTAMP(FROM_UNIXTIME(?) + INTERVAL 1 MONTH) AS tm_end';
                push @sql_param, $p->{tm_start};
            }
             elsif( $p->{mode} == 2 )
            {   # Действует до конца месяца
                $sql .= ', UNIX_TIMESTAMP(LAST_DAY(FROM_UNIXTIME(?)) + INTERVAL 1 DAY) AS tm_end';
                push @sql_param, $p->{tm_start};
            }
             elsif( $p->{period} )
            {
                $sql .= ', UNIX_TIMESTAMP()+? AS tm_end';
                push @sql_param, $p->{period};
            }
            
            my %p = Db->line( $sql, @sql_param );
            %p or last;

            $p->{tm_end} = $p{tm_end};
            $p->{tm1} = $p{tm1};
            $p->{tm2} = $p{tm2};
        }

        my $pay_id = 0;
        if( $actions->{pay} )
        {
            my $p = $actions->{pay};
            if( ref $p ne 'HASH' )
            {
                debug('error', 'Действие pay не является ссылкой на хеш');
                $return_err_hash = {
                    for_adm => 'ошибка модуля услуги',
                    for_usr => 'услуга временно недоступна',
                };
                last;
            }
            my $cash    = $p->{cash} + 0;
            my $category= int $p->{category};
            my $comment = ''.$p->{comment};
            my $creator_ip   = $creator->{ip} || '0.0.0.0';
            my $creator_type = $creator->{type} || 'other';
            my $creator_id   = int $creator->{id};
            my $reason  = ref $p->{reason} eq 'HASH'? $p->{reason} : {};

            $reason->{cash} = $cash;
            if( $p->{discount} )
            {
                # Скидка $p->{discount} %
                $reason->{discount} = $p->{discount};
                $cash = sprintf '%.2f', (1 - $p->{discount}/100) * $cash;
            }

            # Режим уменьшения длительности услуги до 1 числа следующего месяца
            if( ref $actions->{set_service} && $actions->{set_service}{mode} == 2 )
            {
                my %p = %{$actions->{set_service}};
                $p{tm1} == $p{tm2} && last;
                my $k = sprintf "%.2f", ($p{tm2} - $p{tm_start}) / ($p{tm2} - $p{tm1});
                if( $k => 0.01 && $k <= 0.99 )
                {
                    # Неполный месяц, коэффициент $k
                    $reason->{last_day_k} = $k;
                    $cash = sprintf '%.2f', $k * $cash;
                }
            }

            if( lc($p->{mode}) eq 'update' && $service_old{pay_id} )
            {
                $pay_id  = $service_old{pay_id};
                my $rows = Db->do(
                    "UPDATE pays SET cash=cash+? WHERE id=? AND mid=? AND category=? LIMIT 1",
                    $cash, $pay_id, $uid, $category
                );
                $pay_id = 0 if $rows < 1;
            }

            if( $actions->{set_service} )
            {
                $reason->{tm_start} = $actions->{set_service}{tm_start};
                $reason->{tm_end} = $actions->{set_service}{tm_end};
            }

            if( !$pay_id )
            {
                $reason = Debug->dump($reason);
                Db->do(
                    "INSERT INTO pays SET ".
                        "time=UNIX_TIMESTAMP(), ".
                        "mid=?, cash=?, category=?, reason=?, comment=?, creator_ip=INET_ATON(?), creator=?, creator_id=?",
                        $uid, $cash, $category, $reason, $comment, $creator_ip, $creator_type, $creator_id
                ) > 0 or last;
                $pay_id = Db::result->insertid or last;
            }
            
            if( Db->do("UPDATE users SET balance=balance+(?) WHERE id=? LIMIT 1", $cash, $uid) <1 )
            {
                last;
            }
        }

        if( $actions->{set_service} )
        {
            my $p = $actions->{set_service};

            my $tags = ''.$p->{tags};
            $pay_id = $p->{pay_id} if $p->{pay_id};
            my $next_service_id = int $actions->{_set_next_service_id};

            my $sql = "INSERT INTO users_services SET ".
                            "uid=?, service_id=?, next_service_id=?, pay_id=?, tags=?";
            my @sql_param = ( $uid, $service_id, $next_service_id, $pay_id, $tags );

            if( $p->{tm_start} )
            {
                $sql .= ', tm_start=?';
                push @sql_param, $p->{tm_start};
            }
             else
            {
                $sql .= ', tm_start=UNIX_TIMESTAMP()';
            }

            if( $p->{mode} == 1 )
            {   # Срок действия месяц (разное количество дней в месяце)
                $sql .= ', tm_end=UNIX_TIMESTAMP(NOW() + INTERVAL 1 MONTH)';
            }
             elsif( $p->{mode} == 2 )
            {   # Действует до конца месяца
                $sql .= ', tm_end=UNIX_TIMESTAMP(LAST_DAY(FROM_UNIXTIME(?)) + INTERVAL 1 DAY)';
                push @sql_param, $p->{tm_start};
            }
             elsif( $p->{period} )
            {
                $sql .= ', tm_end=UNIX_TIMESTAMP()+?';
                push @sql_param, $p->{period};
            }

            Db->do($sql, @sql_param) > 0 or last;
        }

        $return_err_hash = '';
    }

    if( $return_err_hash || !Db->commit )
    {
        Db->rollback;
        return $return_err_hash;
    }

    return 0;
}


sub get
{
    my(undef, %param) = @_;
    my $services = {};
    my $db = Db->sql("SELECT * FROM services ORDER BY module, title");
    $db->ok or return 0;
    local $SIG{'__DIE__'} = {};
    my $VAR1;
    while( my %p = $db->line )
    {
        $services->{$p{module}} ||= [];
        if( $param{decode} )
        {
            eval $p{param};
            if( $@ )
            {
                debug('error', "Параметры услуги $p{service_id} повреждены: $@");
                $p{param} = {};
            }else
            {
                $p{param} = $VAR1;
            }
        }
        push @{$services->{$p{module}}}, \%p;
    }
    return $services;
}

1;