#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package op;
use strict;
use Debug;
use nod::util;

my $d = {
    name        => 'ip-адреса',
    table       => 'ip_pool',
    field_id    => 'id',
    priv_show   => 'Admin',
    priv_edit   => 'SuperAdmin',
    priv_copy   => 'SuperAdmin',
    allow_copy  => 1,
    sql_get     => "SELECT *, INET_NTOA(ip) AS ipa FROM ip_pool WHERE id=?",
    help_theme  => 'ip_pool',
    menu_create => 'Создать/изменить пул',
    menu_list   => 'Все ip', 
    addsub_del_pool => 1,
};

my $ip_types = {
    static   => 'Статический',
    dynamic  => 'Динамический',
    reserved => 'Зарезервирован',
};

sub o_start
{
 # Сгруппируем существующие ip в диапазоны
 my $db = Db->sql("SELECT ip, INET_NTOA(ip) AS ipa FROM ip_pool ORDER BY ip");
 my $ips = [];
 while( my %p = $db->line )
 {
    push @$ips, \%p;
 }
 my $ip_ranges = nod::util::find_ranges($ips, 'ip');
 foreach my $range( @$ip_ranges )
 {
    push @{$d->{menu}}, [
        $range->[0]{ipa}.' .. '.$range->[1]{ipa}, ip_start=>$range->[0]{ipa}, ip_end=>$range->[1]{ipa},
    ];
 }
 return $d;
}


sub o_list
{
 Doc->template('top_block')->{title} = 'Пул ip адресов';
 my $menu = '';
 my $tbl = $d->{tbl};
 my $url = $d->{url}->new();
 my $sql_where = 'WHERE 1';
 my @sql_param = ();
 
 my($start, $ip_start, $ip_end, $realip, $type) = ses::input('start', 'ip_start', 'ip_end', 'realip', 'type');
 if( $ip_start && $ip_end )
 {
    $sql_where .= " AND ip >= INET_ATON(?) AND ip <= INET_ATON(?)";
    push @sql_param, $ip_start, $ip_end;
    $menu = _("Пул: [filtr|bold] .. [filtr|bold]", $ip_start, $ip_end);
    $url->{ip_start} = $ip_start;
    $url->{ip_end} = $ip_end;
    if( $d->chk_priv('priv_edit') )
    {
        ToRight Menu(
            $url->a('Изменить', op=>'new').
                '<br>'.
            (ses::input('del')? 
                $url->post_a('Удалить?', op=>'del_pool', -class=>'big') : 
                $url->a('Удалить', op=>'list', del=>1)
            )
        );
    }
 }

 if( ses::input_exists('realip') )
 {
    $realip = $realip? 1 : 0;
    $sql_where .= " AND realip = ?";
    push @sql_param, $realip;
    $url->{realip} = $realip;
 }

 if( ses::input_exists('type') )
 {
    $sql_where .= " AND type = ?";
    push @sql_param, $type;
    $url->{type} = $type;
 }

 ToLeft Menu(
    $menu.
    $url->a('Все типы', type => undef, realip => undef, -class=>(!$url->{type} && 'active')).
    $url->a($ip_types->{static},    type => 'static',   -class=>($url->{type} eq 'static'   && 'active')).
    $url->a($ip_types->{dynamic},   type => 'dynamic',  -class=>($url->{type} eq 'dynamic'  && 'active')).
    $url->a($ip_types->{reserved},  type => 'reserved', -class=>($url->{type} eq 'reserved' && 'active')).
    $url->a('Реальные', realip => 1, -class=>($realip eq '1' && 'active')).
    $url->a('Обычные',  realip => 0, -class=>($realip eq '0' && 'active'))
 );

 my $sql = "SELECT *, INET_NTOA(ip) AS ipa FROM ip_pool $sql_where ORDER BY ip";
 my($sql, $page_buttons, $rows, $db) = main::Show_navigate_list([$sql, @sql_param], $start, 24, $url);

 if( $rows < 1)
 {
    Error( scalar @sql_param? 'Фильтру не соответствует ни один ip' : 'В базе данных пока нет ни одного ip' );
 }

 while( my %p = $db->line )
 {
    my $usr = $p{uid}? [ url->a($p{uid}, -ajax=>1, a=>'ajUserInfo', uid=>$p{uid}) ] : '';
    $tbl->add('*', [
        [ '',           'Ip',           $p{ipa}                     ],
        [ '',           'Тип',          $ip_types->{$p{type}}       ],
        [ 'h_center',   'Реальный',     $p{realip}? $lang::yes : '' ],
        [ 'h_center',   'У клиента',    $usr                        ],
        [ 'h_center',   '',             $d->btn_edit($p{id})        ],
        [ 'h_center',   '',             $d->btn_del($p{id})         ],
    ]);
 }

 Show $page_buttons.$tbl->show.$page_buttons;
}


sub o_edit
{
 $d->{name_full} = _('ip [bold]', $d->{d}{ipa});
}


sub o_show
{
 my $tbl = tbl->new( -class=>'data_input_tbl' );

 my $types_list = v::select(
    name     => 'type',
    size     => 1,
    selected => $d->{d}{type},
    options  => $ip_types,
 );

 $tbl->add('', 'll', 'Тип', [ $types_list ] );
 $tbl->add('', 'll',
    'Реальный?',
    [ v::checkbox( name=>'realip', value=>1, checked=>$d->{d}{realip}, label=>$lang::yes) ],
 );

 if( $d->{op} eq 'new' )
 {
    ToRight MessageBox( 'За раз разрешается выбирать не более 1024 ip' );
    $tbl->add('', 'll', 'Начальный ip', [ v::input_t( name=>'ip_start', value=>ses::input('ip_start') ) ]);
    $tbl->add('', 'll', 'Конечный ip',  [ v::input_t( name=>'ip_end',   value=>ses::input('ip_end')   ) ]);
 }
  else
 {
    $tbl->add('','ll', 'ip', [ v::input_t( name=>'ip', value=>$d->{d}{ipa} ) ]);
 }

 $d->chk_priv('priv_edit') && $tbl->add('','C', [ v::submit($lang::btn_save) ]);

 Show Center $d->{url}->form('<br>'.$tbl->show);
}


sub o_update
{
 $d->{sql} = "SET ip=INET_ATON(?), type=?, realip=?";
 push @{$d->{param}}, ses::input('ip'), ses::input('type'), ses::input_int('realip');
}

sub o_insert
{
 my %p = Db->line(
    "SELECT change_ippool(?,?,?,?) AS ok",
    ses::input('ip_start'), ses::input('ip_end'), ses::input('type'), ses::input_int('realip')
 );
 $d->{url}->redirect( ip_start=>ses::input('ip_start'), ip_end=>ses::input('ip_end'),
    $p{ok}? (op=>'list', -made=>'Выполнено') :
            (op=>'new', -error=>1, -made=>'Ошибка. Проверьте правильность ввода ip, также, что конечный номер &gt; начального')
 );
}


sub addsub_del_pool
{
 my($ip_start, $ip_end) = ses::input('ip_start', 'ip_end');
 $d->chk_priv('priv_edit') or Error($lang::err_no_priv);
 # ip записываются в ссылки скриптом, т.е вводится не вручную, поэтому ситуацию не разруливаем красиво
 $ip_start =~ /^\d+\.\d+\.\d+\.\d+$/ or Error('Неверный ip');
 $ip_end =~ /^\d+\.\d+\.\d+\.\d+$/ or Error('Неверный ip');
 my $rows = Db->do(
    "DELETE FROM ip_pool WHERE uid=0 AND ip >= INET_ATON(?) AND ip <= INET_ATON(?)", $ip_start, $ip_end
 );
 $d->{url}->redirect( op=>'list', -made=>"Было удалено $rows ip в пуле $ip_start..$ip_end.<br>".
    "Адреса, выданные клиентам не удалялись. Вы можете снова создать удаленный пул" );
}

1;
