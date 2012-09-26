#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use web::Data;

sub go{

my($url) = @_;
my $Fuid = ses::input_int('id') || ses::input_int('uid') or Error('Клиент не задан');

Doc->template('top_block')->{add_info} = _('id: [b]',$Fuid);

# Если при записи данных была ошибка, то в $ses::data сохранены поля, которые посылались и были изменены.
# $Field_set->{grp}    = 'xxx';
# $Field_errors->{grp} = 'Неверная группа';

my $Field_set = {};
my $Field_errors = {};

if( ref $ses::data eq 'HASH' )
{
    $Field_set    = $ses::data->{fields} || {};
    $Field_errors = $ses::data->{errors} || {};
}

my %priv = %{Adm->priv_hash};
my $priv_edit = Adm->chk_privil('edt_usr') && 1;
# Если нет прав на изменение учетных записей - удалим права на изменение полей
$priv_edit or map{ $priv{$_} = '' }( 71..80 );

my %U = Db->line("SELECT * FROM users WHERE id = ?", $Fuid);
%U or Error($lang::mUser_err_get_data);

!Adm->chk_usr_grp($U{grp}) && !Adm->chk_privil('SuperAdmin') && Error($lang::mUser_err_grp_access);

my $lbl_pass = 'Пароль';
$U{passwd} = '';
$U{contract_date} = $U{contract_date}? the_date($U{contract_date}) : '';

my $grp_property = ','.Ugrp->grp($U{grp})->{property}.',';
if( $grp_property =~ /,5,/ )
{
    debug('Настройки группы запрещают менять группу кроме суперадмина');
    $priv{SuperAdmin} or delete $priv{73};
}

my %N = map{ $_ => defined $Field_set->{$_}? $Field_set->{$_} : $U{$_} } keys %U;

# %U - реальные данные клиента
# %N - еще не сохраненные, со страницы сохранения данных

my $tbl = tbl->new( -class=>'mUser_data_box', -row1=>'', -row2=>'' );


sub old_value
{
    my($name) = @_;
    return v::input_h("old_$name" => $U{$name});
}

sub show_input_field
{   # 0 - право на изменение параметра
    # 1 - заголовок
    # 2 - имя параметра
    my($priv,$title,$name) = @_;
    if( $Field_errors->{$name} )
    {   # при записи в этом поле была ошибка
        $tbl->add('warn', 'L', $Field_errors->{$name});
    }
    my $line = $priv{$priv}? [ old_value($name).v::input_t( name=>$name, value=>$N{$name} ) ] :
        defined $N{$name}? $N{$name} :
        [ _('[span disabled]', $lang::hidden) ];
    $tbl->add('*', 'll', $title, $line);
}

# Adm->usr_grp_list - список групп, доступным данному админу
my @grps = map{ $_ => Ugrp->grp($_)->{name} } Adm->usr_grp_list;
my $grp_list = [ old_value('grp').
    v::select(
        name     => 'grp',
        size     => 1,
        selected => $N{grp},
        nofit    => Ugrp->grp($N{grp})? 'скрыта' : 'ошибка',
        options  => \@grps,
        nochange => !$priv{73},
    )
];
    
$tbl->add('*', 'll', 'Группа', $grp_list);

# --- Доступ в инет ---

my $state = [ old_value('state').
    v::select(
        name     => 'state',
        size     => 1,
        selected => $N{state},
        options  => [ 'on', 'Разрешен', 'off', 'Запрещен' ],
        nochange => !$priv{76},
    )
];
$tbl->add('*', 'll', $lang::lbl_inet_access, $state);

show_input_field(75, $lang::lbl_fio, 'fio');
show_input_field(72, $lang::fullusers_fields_name->{name}, 'name');
show_input_field(71, $lbl_pass, 'passwd');
show_input_field(74, $lang::fullusers_fields_name->{contract}, 'contract');
show_input_field(74, 'Дата договора', 'contract_date');

# --- Отключать при балансе ниже лимита? ---

my $block_if_limit = [ old_value('block_if_limit').
    v::select(
        name     => 'block_if_limit',
        size     => 1,
        selected => $N{block_if_limit},
        options  => [ 1, 'Да', 0, 'Нет' ],
        nochange => !$priv{78},
    )
];
$tbl->add('*', 'll', $lang::lbl_block_if_limit, $block_if_limit);

# --- Авторизация вкл/всегда онлайн ---

my $lstate = [ old_value('lstate').
    v::select(
        name     => 'lstate',
        size     => 1,
        selected => $N{lstate},
        options  => [ 0, 'Включена', '1', 'Всегда онлайн' ],
        nochange => !$priv{77},
    )
];
$tbl->add('*', 'll', $lang::lbl_inet_auth, $lstate);

# --- Состояние ок/подключение/ремонт/... ---

my @cstates = map{ $_ => $lang::cstates{$_} } sort{ !$b || $lang::cstates{$a} cmp $lang::cstates{$b} } keys %lang::cstates;
my $cstate = [ old_value('cstate').
    v::select(
        name     => 'cstate',
        size     => 1,
        selected => $N{cstate},
        options  => \@cstates,
        nochange => !$priv{79},
    )
];
$tbl->add('*', 'll', $lang::lbl_usr_cstate, $cstate);

$tbl->add('*', 'L', $priv{79}? [ old_value('comment').v::input_ta('comment',$N{comment},40,4) ] : $N{comment});

$tbl->add('','C', ['&nbsp;']);
show_input_field(78, 'Скидка, %', 'discount');
show_input_field(78, 'Граница отключения', 'limit_balance');

if( $priv_edit )
{
    $tbl->ins('','C', [ '&nbsp;' ]);
    $tbl->ins('','C', [ v::submit($lang::btn_save) ]);
}

my $form = Center $tbl->show;

$form = Center( url->form(
    -id=>'user_data_form',
    a=>'user_save', uid=>$Fuid,
    $form 
));


ToLeft MessageBox($form);

# =============================================================================
#                               Средняя колонка

# --------------------------- Дополнительные данные ---------------------------


{
 map{ $cfg::Dopfields_tmpl_name{$_} = (split /-/,$cfg::Dopfields_tmpl{$_})[0] } keys %cfg::Dopfields_tmpl;

 # Все доп.поля записи $Fuid
 my $fields = Data->get_fields($Fuid);

 my $UrlDop = url->new();
 
 my $tmpl_class = '';
 my $last_tmpl  = -1;
 my $doptbl = tbl->new(-class=>'td_wide', -row1=>'', -row2=>'');
 foreach my $alias( sort{ $fields->{$a}{order} <=> $fields->{$b}{order} } keys %$fields )
 {
    my $field = $fields->{$alias};
    my $tmpl = $field->{template};
    if( $last_tmpl != $tmpl )
    {   # новый раздел
        $last_tmpl = $tmpl;
        $tmpl_class = "tmpl_$tmpl";
        $doptbl->add('* navmenu', 'E', [ url->a($cfg::Dopfields_tmpl_name{$tmpl}, -base=>'#show_or_hide', -rel=>$tmpl_class) ]);
    }

    my $row_cls = "* $tmpl_class";

    my %p = ();

    #  флаг i - запрет на редактирование поля
    if( $priv{80} && ($field->{flags} !~ /i/ || $priv{SuperAdmin}) )
    {   
        if( defined $Field_set->{$alias} )
        {
            $p{new_value} = $Field_set->{$alias};
        }
        $p{cmd} = 'form';
        $p{iname} = "d$alias";
        $UrlDop->{"o$alias"} = $field->{value};
    }

    my($error,$save_value) = $field->check(%p);
    if( $error )
    {   # ошибка в текущих данных - выведем классом disabled, если в данных, которые пытается сохранить - warn
        my $cls = "$tmpl_class row0 ".($p{new_value}? 'warn' : 'disabled');
        $doptbl->add( $cls, 'L ', $error );
    }

    $doptbl->add($row_cls, 'll', $field->{title}, [ $field->show(%p) ]);
 }


 my $buttons;
 if( $priv{80} )
 {
    $buttons .= v::submit($lang::btn_save);
 }

 my $out = _('[div h_center txtpadding]', $buttons) . 
           _('[div mUser_data_box]', $doptbl->show);

 Show MessageWideBox( Center($UrlDop->form(a=>'user_dop', uid=>$Fuid, -name=>'save', $out)) );

} # --- конец блока допданных ---


# ===========================
#       Правая колонка
# ===========================

# --- Услуги ---

my $domid = 'mUser_srv_list'; # такой же как и в ajUserSrvList.pl
Doc->template('base')->{document_ready} .= "\n nody.ajax({ a:'ajUserSrvList', uid:$Fuid, domid:'$domid' });";
my @urls = ();
push @urls, url->a('Текущие услуги', a=>'ajUserSrvList', uid=>$Fuid, domid=>$domid, -ajax=>1);
Adm->chk_privil(90) && push @urls, url->a('Добавить', a=>'ajUserSrvAdd', uid=>$Fuid, domid=>$domid, -ajax=>1);
ToRight WideBox(
    msg  => _("[div id=$domid][br][]", '', join(' | ',@urls)),
    title=> 'Услуги',
);


# --- ip ---

my $domid = 'mUser_ip_list';
Doc->template('base')->{document_ready} .= "\n nody.ajax({ a:'ajUserIpList', uid:$Fuid, domid:'$domid' });";
my @urls = ();
push @urls, url->a('Текущие ip', a=>'ajUserIpList', uid=>$Fuid, domid=>$domid, -ajax=>1);
if( Adm->chk_privil(81) )
{
    push @urls, url->a('Добавить ip', a=>'ajUserIpAdd', uid=>$Fuid, domid=>$domid, -ajax=>1);
    push @urls, url->a('Добавить реальный ip', a=>'ajUserIpAdd', uid=>$Fuid, domid=>$domid, realip=>1, -ajax=>1);
}
ToRight WideBox(
    msg  => _("[div id=$domid][br][]", '', join(' | ',@urls)),
    title=> 'ip адреса'
);




# --- Трафик ---

my %traf = Db->line("SELECT in1,in2,in3,in4,out1,out2,out3,out4 FROM users_trf WHERE uid=? LIMIT 1", $Fuid);

my $tbl = tbl->new(-class=>'td_wide td_medium fade_border');
$tbl->add('head','crrr', @lang::mUser_traf_header);
foreach my $i( 1..4 )
{
    my @traf = ();
    foreach my $traf( $traf{"in$i"}, $traf{"out$i"} )
    {
        $traf = split_n( $traf );
        $traf =~ s/ /&nbsp;/g; # пробел -> неразрывный пробел
        push @traf, [$traf];
    }
    $tbl->add('','lrr', $cfg::trafname{$i}, @traf);
}

ToRight WideBox( msg=>$tbl->show, title=>'Трафик');


# ---  ---

my $domid = v::get_uniq_id();
Doc->template('base')->{document_ready} .= <<JS;
    nody.ajax({ a:'ajUserInfo2', uid:$Fuid, domid:'$domid' });
JS

ToRight MessageWideBox(_("[div id=$domid]"));

# ===========================
#       Верхнее меню
# ===========================

my $url = url->new( uid=>$Fuid );

my $top_menu = '';
$top_menu .= $url->a('Клиентская статистика', a=>'u_main') if $priv{usr_stat_page};
$top_menu .= $url->a('Пароль', a=>'ajShowPass', -ajax=>1) if $priv{61};
$top_menu .= $url->a('Операции', a=>'ajUserMenu', -ajax=>1);
$top_menu .= $url->a('Платежи и события', a=>'pay_log') if $priv{pay_show};
$top_menu .= $url->a('Бланк настроек', a=>'user_blank', -target=>'blank') if $priv{show_usr_pass};
$top_menu .= $url->a('Трафик', a=>'traf_log');
$top_menu .= $url->a('Удалить!', a=>'user_del') if Adm->chk_privil('SuperAdmin');

ToTop $top_menu;

}
1;
