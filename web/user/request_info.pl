#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head

Плагин запроса у клиента его контактных данных.
Запрашивается только если запись `на подключении` чтобы заблокировать
возможность многократно менять данные

=cut

use strict;
use web::Data;

sub go
{
 my($url,$usr) = @_;
 $usr->{cstate} == 1 or $url->redirect();

 Doc->template('base')->{top_lines} = _('[p]','&nbsp;');

 my $uid = $usr->{id};
 # Список полей таблицы data0, которые необходимо запросить
 my %request_fields = map{ $_ => 1 } @cfg::request_info_from_usr;

 my $fields = Data->get_fields($uid);

 if( ses::input('act') ne 'save' )
 {
    my $tbl = tbl->new( -class=>'pretty td_wide sMain_request_info' );
    $tbl->add('', 'll',
        $lang::lbl_fio,
        [ v::input_t( name=>'fio', value=>$usr->{fio} ) ],
    );
    foreach my $alias( sort{ $fields->{$a}{order} <=> $fields->{$b}{order} } keys %$fields )
    {
        $request_fields{$alias} or next;
        my $field = $fields->{$alias};
        $tbl->add('', 'll',
            $field->{title},
            [ $field->show( cmd=>'form', iname=>$field->{id}) ],
        );
    }
    $tbl->add('', 'C', [ v::submit($lang::btn_save) ]);
    $tbl->ins('big', 'C', $lang::sMain_request_info);

    Show Center Box( msg=>$url->form(act=>'save', $tbl->show) );
    return 1;
 }

 my $change_count = 0;
 foreach my $alias( keys %$fields )
 {
    $request_fields{$alias} or next;
    my $field = $fields->{$alias};
    my $id = $field->{id};
    my $value = ses::input($id);
    defined $value or next;
    $field->{new_value} = $value;
    $change_count++;
 }

 $change_count && Data->save($fields) && $url->redirect( -made=>'Ошибка в введенных вами данных', -error=>1 );

 my $rows = Db->do("UPDATE users SET fio=?, cstate=0, state='on' WHERE id=? LIMIT 1", ses::input('fio'), $uid);
 $rows<1 && $url->redirect( -made=>$lang::err_try_again, -error=>1 );

 $url->redirect( -made=>'Изменения сохранены' );
}

1;
