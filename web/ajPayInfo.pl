#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

return ajModal_window( _proc() );

sub _proc
{
    my $id = ses::input_int('id');
    my %p = Db->line(
        "SELECT p.*,u.grp,INET_NTOA(p.creator_ip) AS creator_addr ".
        "FROM pays p LEFT JOIN users u ON p.mid=u.id WHERE p.id=?",
        $id
    );
    Db->ok or return $lang::err_try_again;
    %p or return "Платеж с id=$id не найден";

    my $admin = Adm->chk_privil('SuperAdmin') || Adm->chk_privil('Admin');
    if( $admin )
    {
    }
     elsif( $p{mid} )
    {
        my $err_msg = Adm->why_no_usr_access($p{grp});
        $err_msg && return $err_msg;
    }
     else
    {
        return $lang::err_no_priv;
    }

    if( ses::input('del') || ses::input('delnow') )
    {
        if( !Adm->chk_privil('SuperAdmin') )
        {
            $p{time}<($ses::t-300) && 
                return 'Только суперадмин может удалить платеж старше 5 минут';
            ($p{creator} ne 'admin' || $p{creator_id} != Adm->id) && 
                return 'Только суперадмин может удалить платеж, который создавал не он';
        }
    }

    if( ses::input('delnow') )
    {
        my @sqls = (
            [ 'DELETE FROM pays WHERE id=? AND ABS(cash-(?))<0.01 LIMIT 1', $id, $p{cash} ]
        );

        $p{mid} && $p{cash}!=0 && push @sqls,
            [ 'UPDATE users SET balance=balance-(?) WHERE id=? LIMIT 1', $p{cash}, $p{mid} ];

        Db->do_all(@sqls) or return $lang::err_try_again;
        ToLog( _('! [] удалил платеж id=[], cash=[], uid=[]', Adm->admin, $id, $p{cash}, $p{mid}) );

        push @$ses::cmd, {
            type => 'js',
            data => 'window.location.reload()',
        };

        return 'Запись удалена';
    }

    my $tbl = tbl->new( -class=>'td_wide td_medium thead', -row1=>'row4', -row2=>'row5' );
    foreach my $k( sort{ $a cmp $b } keys %p )
    {
        $k eq 'creator_ip' && next;
        !$admin && $k !~ /^(id|category|creator)$/ && next;
        $tbl->add('*', [
            ['', 'Поле',     $k ],
            ['', 'Значение', $p{$k} ],
        ]);
    }

    
    if( ses::input('del') )
    {
        $tbl->add('*', 'C', [url->a('Удалить?', a=>ses::cur_module, delnow=>1, id=>$id, -class=>'nav error', -ajax=>1)] );
    }
     else
    {
        $tbl->add('* nav', 'C', [url->a('Удалить', a=>ses::cur_module, id=>$id, del=>1, -class=>'nav', -ajax=>1)] );
    }
    return $tbl->show;
}

1;