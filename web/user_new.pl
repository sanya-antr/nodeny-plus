#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go{

 Adm->chk_privil_or_die('usr_create');

 my @grps = map{ $_ => Ugrp->grp($_)->{name} } Adm->usr_grp_list;

 scalar @grps or Error($lang::mUser_err_no_grp_access);

 my $grp;
 {
    # последний клиент создавался в группе ...
    my %p = Db->line("SELECT reason FROM pays WHERE creator_id=? AND category=411 ORDER BY id DESC LIMIT 1", Adm->id);
    %p or last;
    local $SIG{'__DIE__'} = {};
    my $VAR1;
    eval $p{reason};
    $grp = $VAR1->{grp};
 }

 $grp = $grps[0] if !$grp || !Adm->chk_usr_grp($grp);

 my $grp_list = v::select(
    name     => 'grp',
    size     => 1,
    selected => $grp,
    options  => \@grps,
 );

 my $form = url->form( a=>'user_new_now',
    _($lang::mUser_new_ask, $grp_list, v::submit('сейчас'))
 );

 Show Center $form;

 Doc->template('base')->{main_v_align} = 'middle';
}

1;
