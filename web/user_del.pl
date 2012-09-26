#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

Adm->chk_privil_or_die('SuperAdmin');

my $uid = ses::input_int('uid');

if( !ses::input('go') )
{
    my $info = Get_usr_info($uid) or Error($lang::err_try_again);
    $info->{id} or Error("User id=$uid не найден в базе");
    Error(
        url->form(
            a=>ses::cur_module, go=>1, uid=>$uid,
            _('[p][][br][div h_center]',
                'Вы действительно хотите удалить учетную запись клиента?',
                $info->{full_info},
                v::submit('Удалить'),
            )
        )
    );
}

my %u = Db->line(
    "SELECT u.*,d.*,(`in1`+`in2`+`in3`+`in4`) AS traf ".
    "FROM users u LEFT JOIN data0 d ON u.id=d.uid LEFT JOIN users_trf t on u.id=t.uid ".
    "WHERE u.id=?", $uid,
);
%u or Error($lang::err_try_again);

delete $u{passwd};

my($ok);
{
    Db->begin_work or last;

    Pay_to_DB(
        category=>220, reason=>Debug->dump(\%u),
    ) < 1 && last;

    Db->do( "DELETE FROM data0 WHERE uid=?", $uid );
    Db->ok or last;

    Db->do( "DELETE FROM auth_log WHERE uid=?", $uid );
    Db->ok or last;

    Db->do( "DELETE FROM users_services WHERE uid=?", $uid );
    Db->ok or last;

    Db->do( "DELETE FROM users_trf WHERE uid=?", $uid );
    Db->ok or last;

    Db->do( "DELETE FROM pays WHERE mid=?", $uid );
    Db->ok or last;

    Db->do( "DELETE FROM websessions WHERE uid=? AND role='user'", $uid );
    Db->ok or last;

    Db->do( "UPDATE ip_pool SET uid=0 WHERE uid=?", $uid );
    Db->ok or last;

    Db->do( "DELETE FROM users WHERE id=?", $uid );
    Db->ok or last;

    $ok = 1;
}

if( !$ok || !Db->commit )
{
    Db->rollback;
    return $lang::err_try_again;
}

ToLog( '!! '.Adm->admin._(" удалил клиента с id=[], login=[]", $uid, $u{login}));

url->redirect( a=>'main', -made=>"Учетная запись клиента id=$uid удалена" );


1;
