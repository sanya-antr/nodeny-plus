#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go{

 Adm->chk_privil_or_die('usr_create');

 my $grp = ses::input_int('grp');
 Adm->chk_usr_grp($grp) or Error($lang::mUser_err_grp_access);

 my %N = (
    grp     => $grp,
    state   => 'on',
    cstate  => 1,           # состояние `на подключении`
    lstate  => 0,           # авторизация включена
    limit_balance  => Ugrp->grp($grp)->{block_limit},
    block_if_limit => 0,    # не блокировать при балансе ниже лимита
 );

 my $sql = 'INSERT INTO users SET modify_time=UNIX_TIMESTAMP()';
 my @sql = ();
 foreach my $field( keys %N )
 {
    $sql .= ", $field=?";
    push @sql, $N{$field};
 }

 # --- Генерим пароль ---
 my $lvl = int $cfg::usr_pass_lvl; # уровень сложности пароля ( цифровой/в основном цифры/буквы и цифры)
 # В не самом сложном уровне паролей исключим неоднозначные символы (O и 0, I и l)
 my @s = $lvl < 2?  ( 0..9 ) :
        $lvl < 4?  ( (1..9) x 6,'a'..'k','m','n','p'..'z' ) :
        $lvl < 6?  ( 1..9,'a'..'k','m','n','p'..'z' ) :
        $lvl < 8?  ( 1..9,'A'..'H','J','K','M','N','P'..'Z','a'..'k','m','n','p'..'z' ) :
                   ( 0..9,'A'..'Z','a'..'z' );
 my $passlen = ($lvl % 2? 8 : 5) + int(rand 3);
 my $n = scalar @s;
 my $passwd = join '', map{ $s[rand $n] } ( 1 .. $passlen );
 $sql .= ', passwd=AES_ENCRYPT(?,?)';
 push @sql, $passwd, $cfg::Passwd_Key;

 my($rows, $uid);
 {
    Db->begin_work or last;
    
    $rows = Db->do($sql, @sql);
    $rows < 1 && last;
    $uid = Db::result->insertid;

    # На случай, если менялось автоинкрементное поле в users и админ удалял клиентов вручную или ...
    foreach my $dbtbl( qw{ data0 users_trf auth_log users_services } )
    {
        Db->do("DELETE FROM $dbtbl WHERE uid=?", $uid);
    }
    Db->do("DELETE FROM pays WHERE mid=?", $uid);

    $rows = Db->do("INSERT INTO data0 SET uid=?", $uid);
    $rows < 1 && last;

    $rows = Db->do("INSERT INTO users_trf SET uid=?", $uid);
    $rows < 1 && last;

    $rows = Db->do("INSERT INTO users_limit SET uid=?", $uid);
    $rows < 1 && last;

    # Персональный платежный код в качестве логина
    $rows = Db->do("UPDATE users SET name=? WHERE id=? LIMIT 1", Make_PPC($uid), $uid);
    $rows < 1 && last;

    my $dump = Debug->dump({ grp=>$grp, limit_balance=>$N{limit_balance} });
    $rows = Pay_to_DB( uid=>$uid, category=>411, reason=>$dump );
    $rows < 1 && last;
 }


 if( $rows < 1 || !Db->commit )
 {
    Db->rollback;
    Error($lang::err_try_again);
 }

 url->redirect( a=>'user', uid=>$uid, -made=>'Создана учетная запись' );

}

1;
