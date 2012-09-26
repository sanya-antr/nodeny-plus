#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

# Категория платежа `ошибка ввода кода пополнения`
my $err_pay_category = 305;

sub show_form
{
 my($url,$usr) = @_;
 my $input = v::input_t(name=>'cod').' '.v::submit($lang::btn_go_next);
 $lang::scards_intro =~ s/\{\{input\}\}/$input/;
 Show MessageBox( $url->form($lang::scards_intro) );
 return;
}

sub go
{
 my($Url,$usr) = @_;
 Doc->template('top_block')->{title} .= '. '.$lang::sCards_totop;

 my $uid = $usr->{id};
 $cfg::card_max_tries ||= 10;
 
 my %p = Db->line(
    "SELECT COUNT(*) AS n FROM pays WHERE mid=? AND category=? AND time>(UNIX_TIMESTAMP()-3600*24)", $uid, $err_pay_category
 );
 %p && $p{n} >= $cfg::card_max_tries && Error($lang::sCards_many_errs);

 my $cod = v::trim( ses::input('cod') );
 if( length $cod<4 )
 {
    debug('warn', 'код пополнения должен быть >3 символов');
    return show_form($Url,$usr);
 }

 my %p = Db->line("SELECT * FROM cards WHERE cod=? LIMIT 1", $cod);
 if( !%p )
 {
    Pay_to_DB(uid=>$uid, category=>$err_pay_category, reason=>$cod);
    $Url->redirect( -made=>$lang::sCards_err_cod, -error=>1 );
 }

 $ses::t>$p{tm_end} && Error_($lang::sCards_expired, $cod);
 if( $p{alive} ne 'good' )
 {
    debug('warn','pre', \%p, "\nStop because card is", $lang::card_alives->{$p{alive}});
    $p{alive} eq 'activated' && Error_(
        ($p{uid_activate}==$uid? $lang::scards_already_activated2 : $lang::scards_already_activated), $cod
    );
    Error_($lang::scards_err_state, $cod);
 }

 Db->begin_work or Error($lang::err_try_again);

 my $rows1 = Db->do(
    "UPDATE cards SET alive='activated', tm_activate=UNIX_TIMESTAMP(), uid_activate=? ".
        "WHERE alive='good' AND tm_end>UNIX_TIMESTAMP() AND cod=? LIMIT 1",
    $uid, $cod
 );
 my $rows2 = Db->do(
    "UPDATE users SET state = IF(balance+(?) >= limit_balance, 'on', state),  balance=balance+(?) WHERE id=?",
    $p{money}, $p{money}, $uid
 );

 my $rows3 = Pay_to_DB(uid=>$uid, cash=>$p{money},  category=>99, reason=>$cod);
 
 if( $rows1 < 1 || $rows2 < 1 || $rows3 < 1 || !Db->commit)
 {
    Db->rollback;
    Error($lang::err_try_again)
 }

 $Url->redirect( -made=>_($lang::scards_finish_ok, $p{money}, $cod), a=>'u_main' );
}

1;
