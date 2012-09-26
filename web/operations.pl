#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go{

 my($url) = @_;

 my $act = ses::input('act');

 my %subs = (
    dontshowmess       => 1,    # удалить сообщение для админа от суперадмина
    cards_move_step1   => 1,    # выбор администратора для передачи
    cards_move_step2   => 1,    # непосредственная передача карточек
    cards_move_accept  => 1,    # подтверждение передачи карточек принимающим админом
    cards_change_alive => 1,    # смена состояния карточек (на складе/можно активировать/заблокированы)
    del_ses_data       => 1,
 );

 defined $subs{$act} or return 1;

 $main::{$act}->($url);
 return 1;
}
sub del_ses_data
{
 my($url) = @_;
 Db->do(
    "DELETE FROM webses_data WHERE role=? AND aid=? AND unikey=? LIMIT 1",
    $ses::auth->{role}, $ses::auth->{uid}, ses::input('unikey')
 );
 url->redirect( a=>ses::input('return_to') );
}


# --- Карты пополнения счета ---



sub cards_move_preload
{
 my $start_cid = ses::input_int('start');
 my $end_cid = ses::input_int('end');
 $end_cid ||= $start_cid;
 ($start_cid,$end_cid) = ($end_cid,$start_cid) if $start_cid > $end_cid;
 my $aid = ses::input_int('aid');
 return { start=>$start_cid, end=>$end_cid, aid=>$aid };
}

sub cards_move_step1
{
 my($url) = @_;
 my $cards = cards_move_preload();
 ToTop "Передача карточек пополнения счета с серийными номерами $cards->{start} .. $cards->{end}";
 my $list = '';
 my $i = 0;
 my %p = ( act=>'cards_move_step2', start=>$cards->{start}, end=>$cards->{end} );
 foreach my $aid( @{Adm->list} )
 {
    $aid == Adm->id && next;
    $list .= _('[li]',
        $url->a( Adm->get($aid)->admin, %p, aid=>$aid ).
        (Adm->get($aid)->chk_privil(300) && ' примет без подтверждения')
    );
    $i++;
 }
 $i or Error('Нет ни одного администратора, на которого вы можете оформить передачу карточек.');
 Show MessageBox( $lang::cards_move_intro._('[ul]',$list) );
}

sub cards_move_step2
{
 my($url) = @_;
 my $cards = cards_move_preload();
 ToTop "Передача карточек пополнения счета с серийными номерами $cards->{start} .. $cards->{end}";
 my $aid = $cards->{aid};
 ($aid <=0 || $aid == Adm->id) && Error($lang::cards_move_err_adm_id);
 Adm->get($aid)->chk_privil(116) or Error($lang::cards_move_err_priv1);
 my $where = "WHERE adm_owner=? AND cid>=? AND cid<=?";

 Db->begin_work or Error($lang::err_try_again);

 my($msg, $rows);
 if( Adm->get($aid)->chk_privil(300) )
 {  # не требуется подтверждение передачи.
    # Установим статус "можно активировать", если у админа в правах такое указание
    my $alive = Adm->get($aid)->chk_privil(301)? 'good':'stock';
    $rows = Db->do(
        "UPDATE cards SET alive=?, adm_owner=? $where AND alive IN ('good','stock') AND adm_move=0",
        $alive, $aid, Adm->id, $cards->{start}, $cards->{end}
    );
    $rows += Db->do(
        "UPDATE cards SET adm_owner=? $where AND alive IN ('bad','activated') AND adm_move=0",
        $aid, Adm->id, $cards->{start}, $cards->{end}
    );
    $msg = ' Подтверждение принимающим админом не требуется.';
 }
  else
 {
    $rows = Db->do(
        "UPDATE cards SET adm_move=? $where AND adm_move=0",
        $aid, Adm->id, $cards->{start}, $cards->{end}
    );
    $msg = ' Передачу должен подтвердить принимающий администратор';
   } 
 # категория 521 - "перемещение карточек оплаты"
 $rows = Pay_to_DB( uid=>0, category=>521, reason=>"$cards->{start}:$cards->{end}:$rows:$aid" ) if $rows>0;

 if( $rows<1 || !Db->commit )
 {
    Db->rollback;
    Error("Передача карточек не выполнена. Попробуйте запрос позже.");
 }
 
 $url->redirect( a=>'cards', act=>'list', aid=>Adm->id,
    -made=>"На администратора ".Adm->get($aid)->admin." передано $rows карточек.$msg" );
}

sub cards_move_accept
{
 my($url) = @_;
 my $cards = cards_move_preload();
 my $yes = !!ses::input('yes');
 my $set = $yes? 'adm_move = 0' : 'adm_move = adm_owner';

 Db->begin_work or Error($lang::err_try_again);

 my $rows1 = Db->do(
        "UPDATE cards SET $set, adm_owner=? WHERE cid>=? AND cid<=? AND adm_move=?",
        Adm->id, $cards->{start}, $cards->{end}, Adm->id
 );

 my $rows2 = Pay_to_DB(uid=>0, category=>522, reason=>"$cards->{start}:$cards->{end}:$rows1:$yes");

 if( $rows1<1 || $rows2<1 || !Db->commit )
 {
    Db->rollback;
    Error("Операция не выполнена. Возможно вы послали дублирующий запрос либо внутренняя ошибка.");
 }
 my $msg = ses::input('yes')? "Вы подтвердили прием карточек в количестве $rows1 штук" :
                    "Вы отказались от приема карточек. $rows1 отправлено владельцу обратно. Он должен будет подтвердить причем";
 $url->redirect( a=>'cards', act=>'list', aid=>Adm->id, -made=>$msg );
}


# --- Изменение состояния группы карт оплаты:
# stock : на складе
# bad   : заблокирована
# good  : не активирована
#     Не меняется состояние активированных карт (alive = activated)
# ---

sub cards_change_alive
{
 my($url) = @_;
 my $cards = cards_move_preload();
 my $alive = ses::input('alive') =~ /^(stock|bad)$/? ses::input('alive') : 'good';
 my($start, $end) = ($cards->{start}, $cards->{end});
 
 Db->begin_work or Error($lang::err_try_again);

 my $rows1 = Db->do(
        "UPDATE cards SET alive=? WHERE adm_owner=? AND cid>=? AND cid<=? AND alive IN('good','bad','stock')",
        $alive, Adm->id, $cards->{start}, $cards->{end},
 );
 
 my $rows2 = Pay_to_DB( uid=>0, category=>301, reason=>"$start:$end:$rows1:$alive" );
 
 if( $rows1<1 || $rows2<1 || !Db->commit )
 {
    Db->rollback;
    Error("Операция не выполнена. Возможно вы послали дублирующий запрос либо внутренняя ошибка.");
 }

 my $msg = _(
    "Карты в диапазоне []..[] были переведены в состояние [filtr|commas]. Сменили состояние [] карт",
    $start, $end, $lang::card_alives->{$alive}, $rows1,
 );

 url->redirect( a=>'cards', act=>'group', aid=>Adm->id, start=>$start, end=>$end, -made=>$msg );
}

1;
