#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

my $edt_priv = Adm->chk_privil('SuperAdmin');
$edt_priv or Adm->chk_privil_or_die('Admin');
$edt_priv = '' if !$ses::auth->{adm}{trust};

my $cur_module = ses::cur_module;
my $url = url->new( a=>$cur_module );

Require_web_mod('lang/'.$cfg::Lang.'_admin');

my $menu = join '', map{ $url->a(@$_) } @$lang::adm::main_menu;
ToRight Menu( $menu );

my %subs = (
    list => 1,
    edit => 1,
    save => $edt_priv,
    new  => $edt_priv,
    del  => $edt_priv,
);

my $Fact = ses::input('act');
$Fact = 'list' if ! $subs{$Fact};

main->$Fact;

return 1;

sub list
{
    my $db = Db->sql( 'SELECT * FROM admin ORDER BY login' );
    $db->rows or Error( $db->ok? $lang::adm::no_admin_exists : $lang::err_try_again );
    my $tbl = tbl->new( -class=>'td_wide pretty' );
    while( my %p = $db->line )
    {
        my %priv = map{ $_ => 1 } grep{ $_ } split ',', $p{privil};
        my $priv_count = scalar keys %priv; # количество привилегий на админе
        my $grps_count = $p{usr_grps} =~ s/\d+//g;
        my $url_edt = [ $url->a($subs{save}?'Изменить':'Смотреть', aid=>$p{id}, act=>'edit') ];
        my $url_del = $subs{del} && [ $url->a('Удалить', aid=>$p{id}, act=>'del', login=>$p{login}, -ajax=>1) ];
        $tbl->add('*', [
            [ 'h_center',   'Id',           $p{id}      ],
            [ '',           'Логин',        $p{login}   ],
            [ '',           'Имя',          $p{name}    ],
            #[ '',           'Должность',    $p{post}    ],
            [ 'h_center',   'Привилегий',   $priv_count ],
            [ 'h_center',   'Группы',       $grps_count ],
            [ 'h_center',   'Доступ',       $priv{1} && $lang::yes      ],
            [ 'h_center',   'Админ',        $priv{2} && $lang::yes      ],
            [ 'h_center',   'Суперадмин',   $priv{3} && $lang::yes      ],
            [ 'h_center',   '',             $url_edt    ],
            [ 'h_center',   '',             $url_del    ],
        ]);
    }
    Show Center($tbl->show);
}


sub edit
{
    my $aid = ses::input_int('aid');
    my %p = Db->line(
        "SELECT *,AES_DECRYPT(passwd,?) AS pass FROM admin WHERE id=?",
        $cfg::Passwd_Key, $aid
    );
    %p or Error_( $lang::adm::admin_not_exists, $aid );

    my $tbl = tbl->new( -class=>'td_wide td_medium' );

    if( $subs{save} )
    {
        $tbl->add('', 'C', [ v::submit($lang::btn_save) ]);    
        $tbl->add('', 'L', [ '&nbsp;' ]);
    }

    $tbl->add('*', 'll',
        'Логин',
        [ v::input_t( name=>'login', value=>$p{login} ) ],
    );
    $edt_priv && $tbl->add('*', 'll',
        'Пароль',
        [ v::input_t( name=>'pass', value=>$p{pass} ) ],
    );
    $tbl->add('*', 'll',
        'Имя',
        [ v::input_t( name=>'name', value=>$p{name} ) ],
    );
    $tbl->add('*', 'll',
        'Должность',
        [ v::input_t( name=>'post', value=>$p{post} ) ],
    );

    # --- Доступ к группам --
    {
        my @grps = map{ $_ => Ugrp->grp($_)->{name} } keys %{Ugrp->hash};
        my $usr_grps = v::checkbox_list(
            name    => 'usr_grps',
            list    => \@grps,
            checked => $p{usr_grps},
            buttons => 1,
        );
        $tbl->add('*', 'll',
            'Доступ к группам',
            [ $usr_grps ],
        );
    }

    # --- Привилегии ---
    {
        my @privil = ();
        foreach my $line( @$lang::adm::priv_descr )
        {
            push @privil, $line->{priv} => $line->{title};
        }
        my $privil = v::checkbox_list(
            name    => 'privil',
            list    => \@privil,
            checked => $p{privil},
            buttons => 1,
        );
        $tbl->add('*', 'll',
            'Привилегии',
            [ $privil ],
        );
    }
    
    my $form = $url->form( act=>'save', aid=>$aid, $tbl->show );
    Show Center $form;
}


sub save
{
    my $aid = ses::input_int('aid');
    my @sqls = ();

    my $login = ses::input('login') || 'admin '.int(rand() * 1000);

    my $privil = ses::input('privil');
    $privil =~ s/[^\d,]//g;
    $privil = ",$privil," if $privil;

    my $usr_grps = ses::input('usr_grps');
    $usr_grps =~ s/[^\d,]//g;
    $usr_grps = ",$usr_grps," if $usr_grps;

    my $rows;
    {
        Db->begin_work or last;

        $rows = Db->do(
            "UPDATE admin SET login=?, name=?, post=?, privil=?, usr_grps=?, passwd=AES_ENCRYPT(?,?) WHERE id=?",
            $login, ses::input('name'), ses::input('post'), $privil, $usr_grps, ses::input('pass'), $cfg::Passwd_Key, $aid
        );
        $rows < 1 && last;

        # разряжаем длинную строку без пробелов (для просмотра платежей)
        $privil =~ s/(\d+,\d+,\d+,\d+,\d+,\d+,)/$1 /g;
        my $dump = Debug->dump({
            login    => $login,
            privil   => $privil,
            usr_grps => $usr_grps,
        });
        $rows = Pay_to_DB( uid=>0, category=>551, reason=>$dump );
    }
    if( $rows < 1 || !Db->commit )
    {
        Db->rollback;
        Error($lang::err_try_again);
    }

    ToLog( Adm->admin, "изменил данные админа id = $aid, priv: $privil" );
    $url->redirect( act=>'edit', aid=>$aid, -made=>'Изменения сохранены' );
}


# --- Создание админа ---
sub new
{
    # Если запрос ajax - спросим подтверждение о создании
    if( $ses::ajax )
    {
        my $msg = Center _('[p][div h_center]',
            $lang::adm::admin_create_ask,
            $url->a($lang::yes, act=>'new',  -class=>'nav' ).
                ' '.
            $url->a($lang::no,  act=>'list', -class=>'nav' ),
        );
        push @$ses::cmd, {
            id   => 'modal_window',
            data => $msg,
        };
        return 1;
    }

    # Непосредственно создаем
    
    my($rows, $aid);
    {
        Db->begin_work or last;

        $rows = Db->do("INSERT INTO admin SET login=CONCAT('admin ', FLOOR(RAND()*1000000))");
        $rows < 1 && last;
        $aid = Db::result->insertid;

        $rows = Pay_to_DB( uid=>0, category=>550, reason=>$aid );
        $rows < 1 && last;
    }
    if( $rows < 1 || !Db->commit )
    {
        Db->rollback;
        Error($lang::err_try_again);
    }

    ToLog( Adm->admin, "создал админа id = $aid" );

    $url->redirect( act=>'edit', aid=>$aid, -made=>'Создана административная учетная запись' );
}

# --- Удаление админа ---
sub del
{
    my $aid = ses::input_int('aid');
    Adm->id == $aid && return push @$ses::cmd, { id=>'modal_window', data=>'Суицид?' };
    $url->{aid} = $aid;
    $url->{login} = ses::input('login');
    # Если запрос ajax - спросим подтверждение
    if( $ses::ajax )
    {
        my $msg = _($lang::adm::admin_del_ask, ses::input('login'));
        my $url_yes = ses::input('sure')? 
            $url->a('Удалить?', act=>'del', -class=>'nav error' ) :
            $url->a($lang::yes, act=>'del', sure=>1, -class=>'nav', -ajax=>1 );
        $msg = Center _('[p][div h_center]',
            $msg, $url_yes.' '.$url->a($lang::no,  act=>'list', -class=>'nav' ),
        );
        push @$ses::cmd, {
            id   => 'modal_window',
            data => $msg,
        };
        return 1;
    }

    # Непосредственно удаляем

    my($rows);
    {
        Db->begin_work or last;

        $rows = Db->do("DELETE FROM admin WHERE id=? LIMIT 1", $aid);
        $rows < 1 && last;

        $rows = Pay_to_DB( uid=>0, category=>552, reason=>$aid );
        $rows < 1 && last;
    }
    if( $rows < 1 || !Db->commit )
    {
        Db->rollback;
        Error($lang::err_try_again);
    }

    Db->do("DELETE FROM websessions WHERE role='admin' AND uid=?", $aid);

    ToLog( Adm->admin, "удалил админа id = $aid" );

    $url->redirect( act=>'list', -made=>"Учетная запись администратора id = $aid удалена" );
}

1;