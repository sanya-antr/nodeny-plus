#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head
    Запись допполей.

    Значения полей присылаются в ввиде:
d_login = new_val
o_login = old_val

    где:
_login  : имя поля по таблице datasetup
new_val : устанавливаемое значение поля
old_val : значение поля на момент отображения администратору

=cut

use strict;
use web::Data;

Adm->chk_privil_or_die('edt_usr');    # изменение данных клиента
Adm->chk_privil_or_die(80);           # изменение доп.данных

my $uid = ses::input_int('uid');

my $err = Adm->why_no_usr_access($uid);
$err && Error($err);

my $Goto_user_page = { a=>'user', uid=>$uid };

# Все допполя клиента
my $fields = Data->get_fields($uid);
my $changed_fields = {};
my $errors = 0;
foreach my $alias( keys %$fields )
{
    my $field = $fields->{$alias};
    my $value = ses::input("d$alias");
    defined $value or next;
    # флаг i - только чтение параметра
    $field->{flag}{i} && !Adm->chk_privil('SuperAdmin') && next;

    # save_value уже обработанное значение, будет записано в БД
    my($error, $save_value) = $field->check( new_value => $value );
    if( $error )
    {
        $errors++;
    }
     elsif( ses::input("o$alias") eq $save_value )
    {   # записываемое значение = текущему, т.е поле не меняется
        next;
    }
     else
    {
        $field->{new_value} = $value;
    }
    $changed_fields->{$alias} = $value;
}

keys %$changed_fields or url->redirect( %$Goto_user_page, -made=>'Вы не изменили ни одно из значений' );

{
    $errors && last;
    my $err_msg = Data->save($fields);
    $err_msg && last;
    my $dump = Debug->dump($changed_fields);
    Pay_to_DB( uid=>$uid, category=>412, reason=>$dump );
    url->redirect( %$Goto_user_page, -made=>'Изменения сохранены' );
}

# Необходимо вернуться на страницу изменения данных и таблице webses_data передать
# все посланные клиентом данные, чтобы ему не пришлось заново вводить.
my $unikey = Save_webses_data( module=>'user', data => {
    fields => $changed_fields,
    -F => $Goto_user_page,
    -made => {
        msg => 'Данные не сохранены. Необходимо исправить ошибки',
        error => 1, created => $ses::t
    }
});

url->redirect( _unikey=>$unikey );

1;
