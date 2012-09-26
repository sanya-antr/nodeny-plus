#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

my $res = '';

sub res
{
    my($ok, $msg) = @_;
    $res .= _('[li]', $ok? $msg : _('[span error] []', 'error', $msg) ); 
}

sub go
{
 my($url) = @_;

 res( 0, '&larr; если будет ошибка, она будет выглядеть так');

 my $db = Db->new(
    host    => $cfg::Db_server,
    user    => $cfg::Db_user,
    pass    => $cfg::Db_pw,
    db      => $cfg::Db_name,
    timeout => $cfg::Db_connect_timeout,
    tries   => 1,
    global  => 0,
 );

 # Сохраним выборку в отдельной переменной и в самом конце проверим, что все действия с БД никак не повлияли на эти данные
 # Имя колонки и значение берем уникальные (в пределах текущего теста)

 my $dbres_local = $db->sql('SELECT 123 AS test_col FROM users WHERE id>? LIMIT 1', 0);

 Db->disconnect;

 res( !Db->is_connected && $db->is_connected, 'Глобальное соединение отсоединили, локальное соеденено');

 Db->connect;

 res( Db->is_connected && ref Db->dbh, 'Коннект глобального соединения');


 # --- иной вариант вызова Db->sql

 my $dbres = Db->sql({sql=>'SELECT 1 FROM users WHERE id>? LIMIT 1', param=>[0], comment=>'Тестирование sql_0'});

 res( $dbres->ok, 'sql_1 выполнен');
 res( $dbres->rows == 1, 'sql_1 вернул 1 строку');



# --- Выборка нескольких строк

my $dbres = Db->sql('SELECT 5 AS col UNION SELECT 6 AS col');
res( $dbres->ok, 'sql_2 выполнен');
res( $dbres->rows == 2, 'sql_2 вернул 2 строки');
my %p = $dbres->line;
res( !!%p, 'sql_2->line получена 1я строка в виде хеша');
res( $p{col} eq '5' && $dbres->{row}{col} eq '5', 'sql_2 1я строка корректная');
my %p = $dbres->line;
res( !!%p, 'sql_2->line получена 2я строка в виде хеша');
res( $p{col} eq '6', 'sql_2 2я строка корректная');
my %p = $dbres->line;
res( !%p, 'sql_2->line 3я строка должна отсутствовать');

# --- Выборка одной строки

my %p = Db->line("SELECT 'sv' AS col1, ? AS col2", 'efendy');
res( Db->ok, 'sql_3 выполнен');
res( Db->rows == 1, 'sql_3 вернул 1 строку');
res( !!%p, 'sql_3 получена строка в виде хеша');
res( $p{col2} eq 'efendy', 'sql_3 колонка col2 корректная');


# --- Проверка Db->do

my $rows = $db->do("SELECT 1");
res( $rows == 1, 'sql_4 вернул 1 строку');

# --- Проверка некорректного sql

my $rows = Db->do({sql=>"XXX", comment=>'этот запрос не должен выполнится'});
res( $rows < 0, 'sql_5 тестирование некорректного sql');

# --- Корректный sql, но update 0 строк

my $rows = Db->do("UPDATE users SET id=-1 WHERE id=?", -1);
res( $rows == 0, 'sql_6 вернул 0 строк');

# --- Проверка транзакции с отменой ---

res( Db->begin_work, 'Старт транзации');

my $rows = Db->do("INSERT INTO auth_log SET uid=?, ip=?, start=?, end=?", 0 , 0, 1, 2);
res( $rows == 1, 'в транзакции sql_7 INSERT 1 строки');

my $id = Db::result->insertid;
res( $id, "в транзакции sql_7 insertid = $id");
res( Db::result->sth->{mysql_insertid} == $id, "в транзакции sql_7 доп.проверка insertid и доступ к sth");

my @sql = ("SELECT start FROM auth_log WHERE id=? LIMIT 1", $id);
my %p = Db->line(@sql);
res( !!%p, 'в транзакции sql_8 получена строка в виде хеша');
res( $p{start} == 1, 'в транзакции полученные данные совпали с insert-ом');
res( Db->rollback, 'Отмена транзации');
my %p = Db->line(@sql);
res( Db->ok, 'sql_9 выполнен');
res( !%p, 'sql_9 данные не получены т.к. rollback');
res( Db->rows == 0, 'sql_9 вернул 0 строк т.к. rollback');

# --- Проверка транзакции с commit ---

my @sql = (
    [ "UPDATE auth_log SET uid=uid LIMIT 1" ],
    [ "UPDATE auth_log SET id=id LIMIT 1" ],
);
my $ok = Db->do_all(@sql);
res( $ok, 'В глобальном соединении транзакция по do_all выполнена');

my $ok = $db->do_all(@sql);
res( $ok, 'В локальном соединении транзакция по do_all выполнена');

my $ok = Db->do_all(
    [ "UPDATE auth_log SET uid=uid LIMIT 1" ],
    [ "UPDATE auth_log SET id=id WHERE id=? LIMIT 1", -1 ],
);
res( !$ok, 'Транзакция по do_all не выполнена (тест невыполнения)');





# --- Проверка, что запросы на разных соединениях не повлияют друг на друга

# Выбираем разное количество строк с разными данными

my $dbres1 = $db->sql('SELECT -1 AS col UNION SELECT -2 AS col UNION SELECT -3 AS col');
my $dbres2 = Db->sql('SELECT 5 AS col UNION SELECT 6 AS col');

# Проверим, что dbh у разных соединений разный

res( $db->ok && Db->ok && ($db->dbh ne Db->dbh), 'Выполнение двух запросов по двум соединениям: '.$db->dbh.' '.Db->dbh);

res( $dbres1->rows == 3 && Db->rows == 2, 'Получили разное количество строк в разных соединениях');
my %p1 = $dbres1->line;
my %p2 = $dbres2->line;
res( $p1{col} == -1 && $p2{col} == 5, 'Оба запроса вернули корректные данные');



# ---

res( $dbres_local->ok, 'sql_0 проверка, что после всех операций данные не были искажены');
res( $dbres_local->rows == 1, 'sql_0 вернул 1 строку');
my %p = $dbres_local->line;
res( !!%p, 'sql_0->line получена строка в виде хеша');
res( $p{test_col} eq '123' && $dbres_local->{row}{test_col} eq '123', 'sql_0 строка корректная');




Show _('[p bold][ul]', 'Проверка модуля Db', $res);

}

1;