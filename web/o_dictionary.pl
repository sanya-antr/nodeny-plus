#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package op;
use strict;
use Debug;

# За раз можно создать столько пар ключ/значение
my $max_lines_on_page_for_save = 10;

my $d = {
    name        => 'записи в словаре',
    table       => 'dictionary',
    field_id    => 'id',
    priv_show   => 'Admin',
    priv_edit   => 'SuperAdmin',
    priv_copy   => 'SuperAdmin',
    allow_copy  => 1,
    sql_get     => "SELECT * FROM dictionary WHERE id=?",
    menu_create => 'Новая запись', 
    menu_list   => 'Все ключи',
};

# На данный момент в словаре существуют такие типы записей
my @dic_types = ();

sub o_start
{
 my $db = Db->sql("SELECT DISTINCT type FROM dictionary ORDER BY type");
 while( my %p = $db->line )
 {
    push @{$d->{menu}}, [ $p{type}, type => $p{type} ];
    push @dic_types, $p{type};
 }
 $db->{rows} && unshift @{$d->{menu}}, '<br>', 'Словари:';
 return $d;
}

sub o_list
{
 my $tbl = tbl->new( -class=>'td_wide pretty' );
 my $url = $d->{url}->new();

 my $sql_where = 'WHERE 1';
 my @sql_param = ();

 Doc->template('top_block')->{title} = 'Все словари';

 my $Ftype = ses::input('type');
 if( $Ftype )
 {
    $sql_where .= ' AND type=?';
    push @sql_param, $Ftype;
    $url->{type} = $Ftype;
    Doc->template('top_block')->{title} = _('Словарь [filtr|commas]', $Ftype);
    ToLeft Menu( $url->a("Создать в словаре $Ftype", op=>'new', type=>$Ftype) );
 }
 
 my $sql = [ "SELECT * FROM dictionary $sql_where ORDER BY type,k", @sql_param ];
 my($sql, $page_buttons, $rows, $db) = main::Show_navigate_list($sql, ses::input_int('start'), 22, $url);
 
 $rows<1 && Error_("Словарь [filtr|bold] пуст[p h_center]",
    $Ftype, $url->a('Создать запись', op=>'new', type=>$Ftype, -class=>'nav')
 );
 while( my %p = $db->line )
 {
    $tbl->add('*', [
        $Ftype? [] : [ '', 'Словарь', $p{type} ],
        [ '', 'Ключ',       $p{k} ],
        [ '', 'Значение',   $p{v} ],
        [ '', '',           $d->btn_edit($p{id}) ],
        [ '', '',           $d->btn_del($p{id})  ],
    ]);
 }
 Show $page_buttons.$tbl->show.$page_buttons;
}

sub o_new
{
 $d->{d}{type} = ses::input('type');
}

sub o_edit
{
 $d->{name_full} = _('пары [filtr|commas|bold] = [filtr|commas|bold] из словаря [commas|bold]',
    $d->{d}{k}, $d->{d}{v}, $d->{d}{type}
 );
}

sub o_show
{
 my $url = $d->{url};

 my @lines = ({type => 'text',  name => 'type', value => $d->{d}{type}, title => 'Тип'});
 if( $url->{op} eq 'update' )
 {
    push @lines, { type=>'text',  name=>'k', value=>$d->{d}{k}, title=>'Ключ'};
    push @lines, { type=>'text',  name=>'v', value=>$d->{d}{v}, title=>'Значение'};
 }
    else
 {
    map{
        push @lines, {
            type  => 'text2',
            name1 => "k$_", value1 =>'', title1 => 'ключ ',
            name2 => "v$_", value2 =>'', title2 => 'значение ',
        };
    }(0..$max_lines_on_page_for_save-1)
 }
 $d->chk_priv('priv_edit') && push @lines, { type=>'submit', value=>$lang::btn_save};

 my @types = ();
 # если словарь пустой, то в предложения добавим тип street
 @dic_types = ('street') if !scalar @dic_types;
 foreach my $type( @dic_types )
 {
    $type eq '' && next;
    my $f_type = $type;
    $f_type =~ s/(['"])/\\$1/g;
    push @types, url->a($type, -base=>'#', -onclick=>"var m='$f_type'; \$('#dict_form input[name=type]').val(m); return false");
 }

 ToRight Menu(@types);

 Show Center $d->{url}->form(-id=>'dict_form', \@lines);
}

sub o_insert
{
 my $Ftype = v::trim( Db->filtr(ses::input('type')) );
 # если ключ не будет указан - установим по порядку
 my %p = Db->line("SELECT MAX(CAST(k AS UNSIGNED)) AS m FROM dictionary WHERE type='$Ftype' AND k REGEXP '^[[:digit:]]+\$'");
 my $k_index = $p{m} + 1;
 my $sql = '(type,k,v) VALUES';
 foreach my $i( 0..$max_lines_on_page_for_save-1 )
 {
    my $Fk = v::trim( Db->filtr(ses::input("k$i")) );
    my $Fv = v::trim( Db->filtr(ses::input("v$i")) );
    if( $Fk eq '' )
    {
        $Fv eq '' && next;
        $Fk = $k_index++;
    }
    $sql .= "('$Ftype','$Fk','$Fv'),";
 }
 $sql =~ s/,$// or Error('Не введено ни одного значения');

 $d->{sql} = $sql;
}

sub o_update
{
 $d->{sql} = "SET type=?, k=?, v=?";
 push @{$d->{param}}, map{ v::trim($_) } ses::input('type','k','v');
}

1;
