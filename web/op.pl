#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
=head

Порядок вызова:

o_start -> o_list
o_start -> o_prenew     -> o_new  -> o_show
o_start -> o_precopy    -> o_edit -> o_show
o_start -> o_preedit    -> o_edit -> o_show
o_start -> o_preupdate  -> o_update
o_start -> o_preinsert  -> o_insert
o_start -> o_predel     -> o_postdel

любой из вызовов может переопределяться в модуле o_<module>

=cut
package op;
use strict;

my %subs = (
 'test'         => 1,
 'datasetup'    => 2,
 'nets'         => 2,
 'dictionary'   => 2,
 'usr_grp'      => 2,
 'ip_pool'      => 2,
 'places'       => 2,
 'services'     => 2,
);

main->import( qw( _ Error_ Error Show ToTop ToLeft ToRight Menu Center MessageBox MessageWideBox ) );

my $Fact  = ses::input('act');
my $Fop   = ses::input('op');
my $Fid   = ses::input_int('id');

my $url = url->new( a=>ses::cur_module, act=>$Fact );

exists $subs{$Fact} or Error_('Неизвестная команда act = [filtr|bold]', $Fact);
require "$cfg::dir_web/o_$Fact.pl";

#   Получаем такие ключи:
# name          : имя сущности в родительном падеже, например, 'записи в словаре'
# table         : таблица БД
# field_id      : имя ключевого поля, по которому происходит выборка уникального значения, например, 'id'
# sql_get       : sql выборки значения по полю field_id
# sql_all       : [ sql выборки всех значений ]
# allow_copy    : разрешено ли копирование любой строки в таблице
# menu_subs     : пункты будут вставлены в меню, если позволят привилегии админа
# menu          : массив с пунктами меню
# priv_show     : имя привилегии для просмотра данных
# priv_edit     : имя привилегии для изменения данных

my $d = op->o_start();
bless $d;

$d->{op}    = $Fop;
$d->{id}    = $Fid;
$d->{url}   = $url;
$d->{tbl}   = tbl->new( -class=>'td_wide td_medium pretty' );
$d->{name_full} = $d->{name};
$d->{then_url}  = $url->a( $lang::btn_go_next, op=>'list', -class=>'nav', -center=>1 );

my $menu = $d->{menu} ||= [];

unshift @$menu, [ $d->{menu_create}, op=>'new' ] if $d->{menu_create} && $d->chk_priv('priv_edit');
unshift @$menu, [ $d->{menu_list}, op=>'list' ]  if $d->{menu_list};
push @$menu, '<br>', [ $lang::help, a=>'help', theme=>$d->{help_theme}, -ajax=>1 ] if $d->{help_theme};
push @$menu, '<br>', [ 'Главные настройки', a=>'tune' ] if Adm->chk_privil('Admin');

my $show_menu = join '', map{ ref $_ eq 'ARRAY'? $url->a(@$_) : $_ } grep{ $_ } @$menu;

ToLeft( Menu($show_menu) );

my %subs_op = (
    edit   => $d->chk_priv('priv_edit')? 'Изменение' : 'Просмотр',
    new    => 'Создание',
    update => 'Сохранение',
    insert => 'Сохранение',
    del    => 'Удаление',
    copy   => 'Создание копии',
);


my $sub;
if( $Fop && defined($d->{"addsub_$Fop"}) )
{
    $sub = "addsub_$Fop";
}
 elsif( $subs_op{$Fop} )
{
    $sub = 'o_pre'.$Fop;
    $d->{name_action} = $subs_op{$Fop};
    Doc->template('top_block')->{title} = $d->{name_action}.' '.$d->{name};
}
 else
{
    $sub = 'o_list';
    $d->chk_priv('priv_show') or $d->error_priv("Нет привилегии $d->{priv_show}");
}

op->$sub();

return 1;

sub chk_priv
{
 my($d, $priv) = @_;
 return Adm->chk_privil($d->{$priv});
}

sub error_priv
{
 my($d, $debug_msg) = @_;
 defined $debug_msg && debug('warn', $debug_msg);
 Error($lang::err_no_priv);
}


sub o_predel
{
 $d->chk_priv('priv_edit') or $d->error_priv();
 $d->o_getdata($Fid);
 $d->o_edit();
 $d->{no_delete} && Error_('Удаление [] заблокировано системой, поскольку []', $d->{name_full}, $d->{no_delete});
 ses::input_int('now') or Error_(
    'Удаление [][hr space][div h_center]',
    $d->{name_full}, '', $url->form(op=>$Fop, id=>$Fid, now=>1, v::submit('Выполнить'))
 );

 my $ok = Db->do_all(
    [ "DELETE FROM $d->{table} WHERE $d->{field_id}=? LIMIT 1", $d->{id} ],
    [ "INSERT INTO changes SET act='delete', time=unix_timestamp(), tbl=?, fid=?, adm=?, old_data=?",
        $d->{table}, $d->{id}, Adm->id, Debug->dump($d->{d}) ],
 );
 $ok or Error("Удаление $d->{name_full} НЕ выполнено.");
 $d->o_postdel();
 $url->redirect(op=>'list', -made=>"Удаление $d->{name_full} выполнено");
}

sub o_postdel
{
}

sub o_prenew
{
 $d->chk_priv('priv_edit') or $d->error_priv();
 $d->{id} = 0;
 $d->{d} = {};
 $d->o_new();
 $url->{op} = 'insert';
 $url->{id} = 0;
 $d->o_show;
}

sub o_new
{
}

sub o_precopy
{
 $d->chk_priv('priv_edit') or $d->error_priv();
 $d->{allow_copy} or $d->error_priv();
 $d->o_getdata($Fid);
 $d->o_edit();
 $d->{id} = 0;
 $url->{op} = 'insert';
 $url->{id} = 0;
 $d->o_show();
}

sub o_copy
{
}

sub o_preedit
{
 $d->chk_priv('priv_show') or $d->error_priv();
 $d->o_getdata($Fid);
 $d->o_edit();
 if( $d->{no_edit} )
 {
    debug($d->{no_edit});
    $d->{priv_edit} = 0;
 }
 $url->{op} = 'update';
 $url->{id} = $d->{id};
 $d->o_show();
}

sub o_edit
{
}

sub o_show
{
 my $lines = [];
 foreach my $k( keys %{$d->{d}} )
 {
    push @$lines, { type=>'text', value=>$d->{d}{$k}, name=>$k, title=>$k};
 }
 $d->chk_priv('priv_edit') && push @$lines, { type=>'submit', value=>$lang::btn_save};

 Show( MessageBox( $d->{url}->form($lines) ) );
}

sub o_preupdate
{
 $d->chk_priv('priv_edit') or $d->error_priv();
 $d->o_getdata($Fid);
 $d->{param} = [];
 $d->o_update();
 my $sql = $d->{sql};
 push @{$d->{param}}, $d->{id};
 my $rows = Db->do("UPDATE $d->{table} $sql WHERE $d->{field_id}=? LIMIT 1", @{$d->{param}});
 $rows>0 or Error_('Запрос на изменение [] [span error].', $d->{name_full}, 'не выполнен');
 my %p = Db->line($d->{sql_get}, $d->{id});
 my $new_data = %p? Debug->dump(\%p) : '';
 my $old_data = Debug->dump($d->{d});
 Db->do(
    "INSERT INTO changes SET act='edit', time=unix_timestamp(), tbl=?, fid=?, adm=?, new_data=?, old_data=?",
    $d->{table}, $d->{id}, Adm->id, $new_data, $old_data,
 );
 $url->redirect( op=>'edit', id=>$d->{id}, -made=>'Изменения сохранены.'.$d->{errors} );
}

sub o_preinsert
{
 $d->chk_priv('priv_edit') or $d->error_priv();
 $d->{param} = [];
 $d->o_insert();
 my $sql = $d->{sql};
 my $rows = Db->do("INSERT INTO $d->{table} $sql", @{$d->{param}});
 $rows<1 && Error_('Создание [] [span error].[p]', $d->{name}, 'не выполнено', $d->{then_url});
 my $id = Db::result->insertid;
 if( $id )
 {
    my %p = Db->line($d->{sql_get}, $id);
    my $new_data = %p? Debug->dump(\%p) : '';
    Db->do(
        "INSERT INTO changes SET act='create', time=unix_timestamp(), tbl=?, fid=?, adm=?, new_data=?",
        $d->{table}, $id, Adm->id, $new_data,
    );
 }
 $url->redirect( op=>'list', -made=>'Создано' );
}


sub o_list
{
 my $sql = $d->{sql_all} || "SELECT * FROM $d->{table} ORDER BY $d->{field_id}";
 my($sql, $page_buttons, $rows, $db) = main::Show_navigate_list($sql, ses::input_int('start'), 22, $d->{url});
 $rows or $d->{url}->redirect(op=>'new', -made=>'Пока еще не создано ни одной записи '.$d->{name});
 my $tbl = tbl->new( -class=>'td_wide pretty' );
 my(%p, $cols);
 while( my %p = $db->line )
 {
    if( !$cols )
    {
        my @keys = sort{ $a cmp $b } keys %p;
        $cols ||= 'l' x (scalar @keys + 2);
        $tbl->ins('head', $cols, @keys, '', '');
    }
    my @vals = map{ $p{$_} } sort{ $a cmp $b } keys %p;
    $tbl->add('*', $cols,
        @vals,
        $d->btn_edit($p{$d->{field_id}}),
        $d->btn_del($p{$d->{field_id}}),
    );
 }
 Show( MessageBox( $page_buttons.$tbl->show.$page_buttons) );
}

sub o_getdata
{
 my($d, $id) = @_;
 my %p = Db->line($d->{sql_get}, $id);
 Db->ok or $lang::err_try_again;
 if( !%p )
 {  # удалена ли запись?
    %p = Db->line("SELECT time,adm FROM changes WHERE act='delete' AND tbl=? AND fid=?", $d->{table}, $id);
    if( %p )
    {
        my $time = main::the_short_time($p{time}, 1); # здесь единица указывает вставлять слово `сегодня`, если надо
        my $admin = Adm->get($p{adm})->admin;
        $url->redirect( op=>'list',
            -made=>_('[] запись № [] была удалена администратором [bold]', $time, $Fid, $admin)
        );
    }
    $url->redirect( op=>'list', -made=>"Ошибка получения данных записи номер $Fid");
 }
 $d->{d} = \%p;
}



sub btn_edit
{
 my($d, $id) = @_;
 my $btn_title = $d->chk_priv('priv_edit')? 'Изменить' : 'Смотреть';
 return[ $d->{url}->a($btn_title, op=>'edit', id=>$id) ];
}

sub btn_copy
{
 my($d, $id) = @_;
 $d->chk_priv('priv_edit') or return '';
 return[ $d->{url}->a('Копия', op=>'copy', id=>$id) ];
}

sub btn_del
{
 my($d,$id) = @_;
 $d->chk_priv('priv_edit') or return '';
 return[ $d->{url}->a('Удалить', op=>'del', id=>$id) ];
}


1;
