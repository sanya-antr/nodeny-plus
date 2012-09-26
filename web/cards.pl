#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

my $cur_module = ses::cur_module;
my $Url = url->new( a=>$cur_module );

$cfg::card_max_generate ||= 12000; # за раз можно сгенерировать столько карт

my $normal_priv = Adm->chk_privil('cards');
my $super_priv = Adm->chk_privil('SuperAdmin') && $ses::auth->{adm}{trust};

my %subs = (
 'list'     => $normal_priv,    # просмотр карточек
 'group'    => 1,               # список карточек, админ без привилегий может посмотреть свои карты
 'new_ask'  => $super_priv,     # окно с запросом на генерацию карточек
 'new_go'   => $super_priv,     # непосредственная генерация карточек
 'info'     => $normal_priv,
 'del'      => $super_priv,
 'admin'    => $normal_priv,    # выбор админа, по которому необходим отчет
# 'report'   => $normal_priv,
 'help'     => 1,
);

my $Fact = ses::input('act');

$Fact = 'help' if ! $subs{$Fact};

my $menu = '';

$menu .= $Url->a('Генерация карточек',  act=>'new_ask') if $subs{new_ask};
$menu .= $Url->a('Группы карточек',     act=>'group')   if $subs{group};
$menu .= $Url->a('Список карточек',     act=>'list')    if $subs{list};
$menu .= $Url->a('Отчет',               act=>'report')  if $subs{report};
#$menu .= $Url->a('Отчет по админу',     act => 'admin') if $subs{admin};

$menu .= $Url->form( -method=>'get', act=>'list',
    v::input_t( name=>'cid', value=>ses::input('cid') ).' '.v::submit('№ карты')
);

ToLeft Menu($menu);

# Список админов, на которых числится хотя бы одна карта
if( $normal_priv )
{
    my $menu = '';
    my $db = Db->sql('SELECT DISTINCT adm_owner FROM cards');
    while( my %p = $db->line )
    {
        my $aid = $p{adm_owner};
        $menu .= $Url->a( Adm->get($aid)->admin, act=>'group', aid=>$aid );
    }
    $menu && ToLeft Menu($menu);
}

$main::{'cards_'.$Fact}->();

return 1;

sub _check_generate_params
{
 $cfg::card_alphabet =~ s/\s//g;
 $cfg::card_alphabet = '1234567890' if $cfg::card_alphabet eq '';
 $cfg::card_chars ||= 12; # по умолчанию 12 символов в коде
}

sub cards_new_ask
{
 Doc->template('top_block')->{title} = 'Генерация карточек пополнения счета';

 _check_generate_params();
 Show MessageBox( $Url->form( act=>'new_go',
    [
      {type => 'descr',  value => $cfg::card_chars,    title => 'Количество символов в коде пополнения'},
      {type => 'descr',  value => $cfg::card_alphabet, title => 'Алфавит кода пополнения'},
      {type => 'text',   value => ses::input('count'), name => 'count', title => "Количество карточек (максимум $cfg::card_max_generate)"},
      {type => 'text',   value => ses::input('money'), name => 'money', title => "Номинал карточки, $cfg::gr"},
      {type => 'text',   value => ses::input('days'),  name => 'days',  title => 'Срок действия (дней) или дата окончания (dd.mm.gggg)'},
      {type => 'submit', value => 'Сгенерировать'},
    ]
 ));

}

sub cards_new_go
{
 _check_generate_params();

 my $url = $Url->new( act=>'new_ask', -error=>1, count=>ses::input('count'), money=>ses::input('money'), days=>ses::input('days') );
 my $err_msg = 'Карточки не сгенерированы';

 Error('Параметры генерации карточек (длина кода) ненадежны либо заданы неверно. '.$err_msg)
    if $cfg::card_chars>24 || $cfg::card_chars<8;

 my $count = ses::input_int('count');
 if( $count<1 || $count>$cfg::card_max_generate )
 {
    $url->redirect( -made=>"Число карточек для генерации должно быть в пределах 1..$cfg::card_max_generate. ".$err_msg );
 }

 my $money = ses::input('money') + 0;
 if( $money <= 0.01 )
 {
    $url->redirect( -made=>'Денежная сумма на карточке должна быть больше нуля. '.$err_msg );
 }

 my $time = v::trim( ses::input('days') );
 if( $time =~ /^(\d+)\.(\d+)\.(\d+)$/ && $3<2030 && $2<13 && $1<32 )
 {
    eval{ $time = timelocal(59,59,23,$1,$2-1,$3-1900); };
    $time = 0 if $@;
    $time = 0 if $time < $ses::t;
 }
  elsif( $time =~ /^\d+$/ )
 {
    $time = $time*60*60*24 + $ses::t;
 }
  else
 {
    $time = 0;
 }
 if( !$time )
 {
    $url->redirect( -made=>'Срок действия карточек задан неверно. '.$err_msg );
 }

 my @alphabet = split //, $cfg::card_alphabet;
 my $alphabet = scalar @alphabet;
 my $ok = 1;
 my $cid_start = 0;
 my $cid_end = 0;
 Db->begin_work or Error($lang::err_try_again);
 while( $count-- )
 {
    my $cod = '';
    $cod .= $alphabet[rand $alphabet] foreach ( 1 .. $cfg::card_chars );

    $ok = Db->do(
        "INSERT INTO cards (cod, money, tm_create, tm_end, tm_activate, adm_create, alive, adm_owner ) ".
        "VALUES(?, ?, ?, ?, ?, ?, ?, ?)",
        $cod, $money, $ses::t, $time, 0, Adm->id, 'stock', Adm->id
    );

    $ok>0 or last;

    $ok = Db::result->insertid;
    $ok>0 or last;
    
    if( $cid_end && ($ok - $cid_end) != 1 )
    {
        # разрыв последовательности серийных номеров, возможно параллельная генерация карт
        $ok = 0;
        last;
    }
    $cid_end = $ok;
    $cid_start ||= $ok;
 }

 my $count = ses::input_int('count');
 if( $ok>0 )
 {
    $ok = Pay_to_DB( category=>300, reason=>"$cid_start:$cid_end:$money:$count" );
 }
 
 if( $ok<1 || !Db->commit )
 {
    Db->rollback;
    $url->redirect( -made=>'Внутренняя ошибка. '.$err_msg );
 }

 my $msg = "Сгенерировано $count карт номиналом $money $cfg::gr с серийными номерами $cid_start .. $cid_end";
 ToLog( '!! '.Adm->admin.' '.$msg );

 $Url->redirect( act=>'group', -made=>$msg );
} 

# =====================================
#    Список карт пополнения счета
# =====================================

sub cards_list
{
 Doc->template('top_block')->{title} = 'Список карточек пополнения счета';
 $Url->{act} = $Fact;
 my $cid = ses::input_int('cid');
 my $sql = 'SELECT * FROM cards';
 my @orders = (
    'cid'           => 'Серийный №',
    'money'         => 'Номинал',
    'tm_create'     => 'Созданы',
    'tm_end'        => 'Окончание действия',
    'tm_activate'   => 'Время активации',
    'alive'         => 'Статус',
 );
 my %orders = @orders;
 my $order = ses::input('order');
 my $order_up = ses::input_int('order_up');
 $order = $orders{$order}? $order : 'cid';
 my $url = $Url->new( order=>$order, order_up=>$order_up );
 if( $cid > 0 )
 {
    $url->{cid} = $cid;
    Doc->template('top_block')->{title} = "Поиск карточки по номеру : $cid";
    $sql .= " WHERE cid=$cid";
 }

 $sql .= ' ORDER BY '.$order.($order_up? '' : ' DESC');

 my $tbl = tbl->new( -class=>'border td_tall td_wide width100' );
 my($sql,$page_buttons,$rows,$db) = Show_navigate_list($sql, ses::input_int('start'), 30, $url);
 $rows>0 or return;
 while( my %p = $db->line )
 {
    my $alive = $p{alive};
    my $status = $lang::card_alives->{$alive};
    $status .= ' (expired)' if $alive ne 'activated' && $p{tm_end} < $ses::t;

    my $domid = v::get_uniq_id();
    $status = [ _("[span id=$domid]", v::filtr($status)) ];
    my $info = $super_priv? [ url->a('info', a=>'ajCardInfo', cid=>$p{cid}, domid=>$domid, -ajax=>1) ] : '';

    $tbl->add('*','crrrrlc',
        $p{cid},
        $p{money},
        the_date($p{tm_create}),
        the_date($p{tm_end}),
        $alive eq 'activated' && the_time($p{tm_activate}),
        $status,
        $info,
    );
 }

 my @cells = ();
 while( my $ord = shift @orders)
 {
    my $title = shift @orders;
    $title .= $order_up? ' &uarr;' : ' &darr;' if $order eq $ord;
    push @cells, [ $Url->a([$title], order=>$ord, order_up=>!$order_up) ];
 }
 my $cells = scalar @cells;
 $tbl->ins('head', 'c'.('r' x ($cells-2)).'l ', @cells, 'Info');

 Show $page_buttons.$tbl->show.$page_buttons;
}


sub cards_report
{
 my $Fyear = ses::input_int('year') || $ses::year_now;
 my $Fmon  = ses::input_int('mon') || $ses::mon_now;
 my $mon_list  = Set_mon_in_list($Fmon);
 my $year_list = Set_year_in_list($Fyear);

 $Url->{act}  = ses::input('act');
 $Url->{mon}  = $Fmon;
 $Url->{year} = $Fyear;
 
 # начало месяца
 my $time1 = "UNIX_TIMESTAMP('$Fyear-$Fmon-1 00:00:00')";
 # начало следущего месяца
 my $time2 = "UNIX_TIMESTAMP(DATE_ADD('$Fyear-$Fmon-1 00:00:00', INTERVAL 1 MONTH))";

 if( ses::input('filtr') eq 'admin' )
 {
    my $aid = ses::input_int('aid');
    my $sql = "SELECT COUNT(*) AS n, SUM(money) AS m FROM cards WHERE adm_owner=? AND ";
    my @f = (
        ["alive='good'",        'Не активированных карточек',   '(карточки могут быть уже реализованы, но не активированы)'],
        ["alive='stock'",       'В состоянии на `складе`',      '(карточки пока не могут быть активированны)'],
        ["alive='bad'",         'Заблокированных карточек',     '(эти карточки не активированы и не могут быть активированы)'],
        ["alive='activated'",   'Активированные карточки',      '(за весь период деятельности реализатора)'],
        ["alive='activated' AND tm_activate>=$time1 AND tm_activate<$time2", 'Активированные в указанном месяце'],
    );

    my $tbl = tbl->new( -class=> 'td_tall td_wide' );
    $tbl->add('head','ccc', Adm->get($aid)->admin, 'Количество', "Сумма, $cfg::gr");
    while( my $p = shift @f )
    {
        my %p = Db->line( $sql.$p->[0], $aid );
        $tbl->add('*','lrr', [_('[][div disabled]',$p->[1],$p->[2])], $p{n}, $p{m});
    }
    Show $tbl->show;
    my @form_time = ( -method=>'get', filtr=>'admin', aid=>$aid, "$mon_list $year_list ".v::submit('Показать') );
    ToTop $Url->form(@form_time);
    return;
 }

 if( !ses::input('filtr') )
 {
    my $sql = "SELECT SUM(c.money) AS m, u.grp FROM cards c LEFT JOIN users u ON c.uid_activate=u.id \n".
        "WHERE c.alive='activated' AND c.tm_activate >= $time1 AND c.tm_activate < $time2 GROUP BY u.grp";
    my $db = Db->sql($sql);
    my $tbl = tbl->new( -class=> 'td_tall td_wide' );
    while( my %p = $db->line )
    {
        my $m = $p{m};
        my $grp = $p{grp};
        defined $grp or next;
        my $tbl2 = tbl->new( -class=> 'td_medium td_narrow' );
        if( !ses::input('n') )
        {
            my $db2 = Db->sql(
                "SELECT SUM(c.money) AS m, c.adm_owner FROM cards c LEFT JOIN users u ON c.uid_activate=u.id \n".
                    "WHERE c.alive='activated' AND u.grp=? AND tm_activate>=$time1 AND tm_activate<$time2 GROUP BY c.adm_owner",
                $grp
            );
            while( my %p2 = $db2->line )
            {
                my $aid = $p2{adm_owner};
                my $adm = Adm->get($aid);
                $adm = $Url->a($adm->admin, filtr=>'r', id=>$aid);
                $tbl2->add('','ll', [$adm],$p2{m});
            }
        }else
        {
            my $db2 = Db->sql(
                "SELECT COUNT(c.money) AS n, c.money AS m FROM cards c LEFT JOIN users u ON c.uid_activate=u.id \n".
                    "WHERE c.alive='activated' AND u.grp=? AND tm_activate >= $time1 AND tm_activate < $time2 GROUP BY c.money",
                $grp
            );
            while( my %p2 = $db2->line )
            {
                $tbl2->add('','lllll', $p2{n}, '*', $p2{m}, '=', $p2{n} * $p2{m});
            }
        }
        $tbl->add('*','l r', Ugrp->grp($grp)->{name}, [$tbl2->show], $p{m});
    }
     my @form_time = ( -method=>'get', "$mon_list $year_list ".v::submit('Показать').
        $Url->a('По реализаторам').
        $Url->a('По номиналам', n=>1)
    );
    ToTop div('nav', $Url->form(@form_time) );
    if( !$tbl->{data} )
    {
        Show MessageBox( 'За выбранный период нет данных' );
        Exit();
    }
    $tbl->ins('head','llr',
        'Группа клиентов',
        ses::input('n')? 'Карточки' : "Реализатор / $cfg::gr",
        "Активировано карточек на сумму, $cfg::gr"
    );
    Show $tbl->show;
    return;
   }

}

sub cards_group
{
 my $Faid   = Adm->chk_privil('cards')? ses::input_int('aid') : Adm->id;
 my $Fmove  = !!ses::input('move');
 my $Fstart = ses::input_int('start') || '';
 my $Fend   = ses::input_int('end') || '';
 ($Fend, $Fstart) = ($Fstart, $Fend) if $Fstart > $Fend && $Fend > 0;
 my $totop  = 'Карты пополнения';
 my $where  = 'WHERE 1';
 $where .= " AND cid>=$Fstart" if $Fstart;
 $where .= " AND cid<=$Fend" if $Fend;
 $totop .=  $Fstart && $Fend ? " в диапазоне $Fstart .. $Fend" :
            $Fstart ? " в серийными номерами от $Fstart" :
            $Fend? " в серийными номерами до $Fend" : '';

 if( $Faid )
 {
    $where .= " AND (adm_owner = $Faid OR adm_move = $Faid)";
    $totop = _('[] у администратора [bold]', $totop, Adm->get($Faid)->admin);
 }
 if( $Fmove )
 {
    $totop .= ' в состоянии перемещения';
    $where .= ' AND adm_move<>0';
 }

 my %url = ( act=>ses::input('act'), aid=>ses::input('aid'), move=>$Fmove, start=>$Fstart, end=>$Fend );
 ToTop _('[big]', $totop);
 ToLeft MessageWideBox(
    _('[div navmenu]',
        $Url->a($Fmove? 'Все карты':'Передающиеся карты', %url, move=>!$Fmove)
    ).
    $Url->form( %url, -method=>'get', [
        { type=>'text',   value=>$Fstart, name=>'start', title=>['Начальный&nbsp;№'] },
        { type=>'text',   value=>$Fend,   name=>'end',   title=>['Конечный&nbsp;№']  },
        { type=>'submit', value=>'Фильтр'},
    ])
 );

 my $tbl = tbl->new( -class=>'pretty td_tall td_wide' );
 my $db = Db->sql("SELECT * FROM cards $where ORDER BY cid");
 my $rows = $db->{rows};
 my %last = ();
 my %counters = ();
 my $i = 0;
 my $row_def = 'rcrclc';
 while( my %p = $db->line )
 {
    $i or next;

    $p{adm_move}  == $last{adm_move} && 
    $p{adm_owner} == $last{adm_owner} && 
    $p{money}     == $last{money} && 
    ($p{cid}-$last{cid}) == 1 && 
        next;

    my $aid   = $last{adm_owner};
    my $start = $last{cid} - $i + 1;
    my $end   = $last{cid};

    my $tbl2 = tbl->new( -class=>'width100 td_ok' );
    map{ $tbl2->add('', 'rl', $counters{$_}, $lang::card_alives->{$_}) } keys %counters;
    my $comment = $tbl2->show;

    $comment .= _('[br][span disabled] [] &rarr; []',
        'Передаются', Adm->get($last{adm_owner})->url, Adm->get($last{adm_move})->url
    ) if $last{adm_move};
    my $actions = '';
    my %url = ( a=>'operations', start=>$start, end=>$end );
    if( $last{adm_move} )
    {
        if( $last{adm_move} == Adm->id && 0 )
        {
            $actions .= _('[]&nbsp;&nbsp;&nbsp;[]',
                $Url->a('Принять',    %url, act=>'cards_move_accept', yes=>1),
                $Url->a('Отказаться', %url, act=>'cards_move_accept', yes=>0)
            );
        }
    }
     elsif( $last{adm_owner} == Adm->id )
    {
        #$actions .= $Url->a('Передать', %url, act=>'cards_move_step1');
        foreach my $act(
            [ good  => 'В работу'],
            [ stock => 'На склад'],
            [ bad   => 'Блокировать'],
        ){
            $actions .= '&nbsp;&nbsp;&nbsp;'.$Url->a($act->[1], %url, act=>'cards_change_alive', alive=>$act->[0]);
        }
    }
    $tbl->add( '*', $row_def,
        "$start .. $end",
        $i,
        $last{money} + 0,
        [Adm->get($aid)->url],
        [$comment],
        [$actions],
    );
    $i = 0;
    %counters = ();
 }
  continue
 {
    $i++;
    %last = %p;
    $counters{$p{alive}}++;
    --$rows or redo;
 } 

 $tbl->{data} or return;
 $tbl->ins('head',$row_def,
    'Диапазон',
    'Штук',
    $cfg::gr,
    'Числятся на админе',
    'Комментарий',
    'Действие'
  );

 my $db = Db->sql("SELECT alive, money, COUNT(*) AS n FROM cards $where GROUP BY alive, money ORDER BY alive, money");
 my $rows = $db->{rows};
 my $last_alive;
 my($sum, $i) = (0,0);
 my $tbl1 = tbl->new( -class=> 'td_medium td_wide' );
 $tbl1->add('head','lrr', 'Состояние', 'Шт', ["&sum;, $cfg::gr"]);
 my $tbl2 = tbl->new( -class=>'td_medium td_wide' );
 while( my %p = $db->line )
 {
    if( !$rows || $last_alive ne $p{alive} )
    {
        $sum && $tbl1->add( '*', 'lrr', $lang::card_alives->{$last_alive}, $i, $sum);
        $rows or last;
        $tbl2->add( '', '3', ['&nbsp;']);
        $tbl2->add( 'data2', '3', $lang::card_alives->{$p{alive}} );
        $tbl2->add('head','ccc', "Номинал, $cfg::gr", 'Кол-во', ["&sum;, $cfg::gr"]);
        $sum = 0;
        $i = 0;
    }

    # +0 убирает точку-разделитель, если номинал целое число
    $tbl2->add( '*', 'rrr',
        $p{money} + 0,
        $p{n},
        $p{money} * $p{n},
    );
    $sum += $p{money} * $p{n};
    $i += $p{n};
 }
  continue
 {
    $last_alive = $p{alive};
    --$rows or redo;
 } 
 Show Center( $tbl->show );
 ToLeft MessageWideBox( $tbl1->show.$tbl2->show );
}


sub cards_help
{
}

1;
