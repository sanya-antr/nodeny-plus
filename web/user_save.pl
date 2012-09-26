#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go{

Adm->chk_privil_or_die('edt_usr');

my $Fuid = ses::input_int('uid');

my $url = url->new( a=>'user', uid=>$Fuid );

my %U = Db->line("SELECT *, AES_DECRYPT(passwd,?) AS pass FROM users WHERE id = ?", $cfg::Passwd_Key, $Fuid);
%U or Error($lang::mUser_err_get_data);
$U{passwd} = $U{pass};
my $grp = $U{grp};

my %priv = %{Adm->priv_hash};

my $grp_property = ','.Ugrp->grp($grp)->{property}.',';
# Настройки группы запрещают менять группу кроме суперадмина
!$priv{SuperAdmin} && $grp_property =~ /,5,/ && delete $priv{73};

!Adm->chk_usr_grp($grp) && !Adm->chk_privil('SuperAdmin') && Error($lang::mUser_err_grp_access);

my $top_log = '';

my %errors = ();

my $f = {
    grp             => { priv => 73, type => 'int',  min => 1 },
    name            => { priv => 72 },
    passwd          => { priv => 71 },
    fio             => { priv => 75 },
    state           => { priv => 76, type => 'hash', hash => { 'on' => 1, 'off' => 1 } },
    discount        => { priv => 78, type => 'int',  max => 100, min => 0 },
    cstate          => { priv => 79, type => 'hash', hash => \%lang::cstates },
    lstate          => { priv => 77, type => 'int',  max => 1, min => 0 },
    comment         => { priv => 79 },
    balance         => { priv => 3  },
    limit_balance   => { priv => 78 },
    block_if_limit  => { priv => 78, type => 'int',  max => 1, min => 0 },
    contract        => { priv => 74 },
    contract_date   => { priv => 74 },
};

# %N заполняем присланными данными если:
#   переменная $F{field} определена т.к. перед посылкой админу могли дать право на изменение поля
#   право на изменение поля
#   $F{old_field} ne $F{field}

my %N = ();
foreach my $i( keys %$f )
{
    ses::input_exists($i) or next;
    $priv{$f->{$i}{priv}} or next;
    my $val = ses::input($i);
    my $type = $f->{$i}{type};
    if( $type eq 'int' )
    {
        if( $val !~ m|^\-?(\d+)$| )
        {
            $errors{$i} = 'необходимо ввести целое число';
        }
         else
        {
            if( defined $f->{$i}{max} && $val > $f->{$i}{max} )
            {
                $errors{$i} = "max value: $f->{$i}{max}";
            }
            if( defined $f->{$i}{min} && $val < $f->{$i}{min} )
            {
                $errors{$i} = "min value: $f->{$i}{min}";
            }
        }
    }
     elsif( $type eq 'hash' )
    {
        defined $f->{$i}{hash}{$val} or next;
    }
    ses::input("old_$i") eq $val && next;
    $N{$i} = $val;
}


defined $N{grp} && !Adm->chk_usr_grp($N{grp}) && delete $N{grp};

$grp = defined $N{grp}? $N{grp} : $U{grp};

{
    defined $N{name}  or last;
    $N{name} = v::trim($N{name});
    $top_log .= ' Убраны пробелы в начале и конце логина' if $N{name} ne ses::input('name');
    $top_log .= ' Убраны пробелы в логине' if $cfg::Block_space_login && $N{name} =~ s|\s||g;
    if( $N{name} eq '' )
    {
        $errors{name} = 'необходимо заполнить';
        last;
    }
    if( $cfg::Only_latin_login && $N{name} =~ /\W/ )
    {
        $errors{name} = 'разрешены только латиница и цифры';
        last;
    }
    if( Db->line("SELECT id FROM users WHERE name=? AND id<>? LIMIT 1", $N{name}, $Fuid) )
    {
        $errors{name} = 'принадлежит другому клиенту';
        last;
    }
}


{
    defined $N{contract_date} or last;
    $N{contract_date} =~ s| ||g;
    if( $N{contract_date} eq '' )
    {
        $N{contract_date} = 0;
        last;
    }
    if( $N{contract_date} =~ m|^(\d+)[\./](\d+)[\./](\d+)$| && eval{ $_= timelocal(0,0,0, $1, $2-1, $3>1900? $3 : $3+100) } )
    {
        $N{contract_date} = $_;
    }
     else
    {
        $errors{contract_date} = 'задана неверно';
    }
}

{
    defined $N{balance} or next;
    if( $N{balance} !~ m|^-?\d+(\.\d)?\d*$| )
    {
        $errors{balance} = 'задан неверно';
        last;
    }
}

{
    defined $N{limit_balance} or next;
    if( $N{limit_balance} !~ m|^-?\d+(\.\d)?\d*$| )
    {
        $errors{limit_balance} = 'задана неверно';
        last;
    }
}

if( keys %errors )
{
    my $unikey = Save_webses_data( module=>'user', data => {
        fields => \%N, errors => \%errors,
        -F => { uid => $Fuid },
        -made => {
            msg     => 'Данные не сохранены. Необходимо исправить ошибки',
            error   => 1,
            created => $ses::t,
        }
    });
    url->redirect( _unikey=>$unikey );
}

my $sql;
my @sql;

if( defined $N{passwd} )
{
    $sql .= ', ' if $sql;
    $sql .= 'passwd=AES_ENCRYPT(?,?)';
    push @sql, $N{passwd}, $cfg::Passwd_Key;
    # в событии скрываем пароль
    $N{passwd} = 'xxx';
}

if( defined $N{cstate} )
{
    $sql .= ', ' if $sql;
    $sql .= 'cstate_time=UNIX_TIMESTAMP()';
}
 elsif( defined $N{comment} && $N{comment} eq '' && $U{cstate} == 2 )
{   # Сейчас был удален комментарий, а текущее состояние `читай комментарии` и оно не меняется - установим в `Все ок`
    $N{cstate} = 0;
}

my $dump = Debug->dump(\%N);

delete $N{passwd};

foreach my $i( keys %N )
{
    $sql .= ', ' if $sql;
    $sql .= "$i=?";
    push @sql, $N{$i};
}

$sql or $url->redirect( -made=>'Никакие данные не были изменены.'.$top_log );

$sql .= ', modify_time=UNIX_TIMESTAMP()';

$sql = "UPDATE users SET $sql WHERE id = ? LIMIT 1";
push @sql, $Fuid;

my $ok = 0;

{
    Db->begin_work or last;
    Db->do( $sql, @sql )
        < 1 && last;
    Db->do( "UPDATE users_trf SET actual=0 WHERE uid=? LIMIT 1", $Fuid )
        < 1 && last;
    Pay_to_DB( uid=>$Fuid, category=>410, reason=>$dump )
        < 1 && last;
    $ok = 1;
}

if( !$ok || !Db->commit )
{
    Db->rollback;
    Error($lang::err_try_again);
}

$url->redirect( -made=>'Данные сохранены.'.$top_log );

}
1;
