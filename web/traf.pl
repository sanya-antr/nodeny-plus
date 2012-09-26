#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

# Какие поля fullusers можно показывать в таблице трафика
$cfg::_fullusers_fields = {
    id   => 'id',
    name => 'name',
    fio  => 'fio',
    ALL  => 'ALL',
};

$cfg::_ip_proto = {
    1  => 'icmp',
    6  => 'tcp',
    17 => 'udp',
};

my @ToLeft  = ();
my @ToRight = ();

push @{$ses::subs->{exit}}, sub
{
    ToLeft  join '', @ToLeft;
    ToRight join '', @ToRight;
};

push @ToLeft, Menu(
    url->a('График', a=>'traf_log').
    url->a('Последний срез', a=>'traf')
);

my $url = url->new( a=>ses::cur_module );

my $sql_where = '';

# Детализировать трафик?
my $Fdetail = ses::input_int('detail');
$url->{detail} = $Fdetail || undef;

my $traf_tbl_type = $Fdetail? 'Z':'X';

# Внимание: $Fusr_field попадает в sql без фильтрации, хеш страхует
my $Fusr_field = $cfg::_fullusers_fields->{ses::input('usr_field')} || 'name';
$url->{usr_field} = $Fusr_field if $Fusr_field ne 'name';

my $Ftraf_cls = ses::input_int('traf_cls');
if( $Ftraf_cls )
{   # Трафик по направлению $Ftraf_cls или сумма, если = 0
    $url->{traf_cls} = $Ftraf_cls;
    $sql_where .= " AND class = $Ftraf_cls";
}

my $Ftm_stat = ses::input_int('tm_stat') || $ses::t;
my $t = localtime($Ftm_stat);
my($day, $mon, $year) = ($t->mday, $t->mon+1, $t->year+1900);
my $traf_tbl_name = sprintf $traf_tbl_type.'%s_%s_%s', $year, $mon, $day;
my %p = Db->line("SELECT MAX(time) AS t FROM $traf_tbl_name WHERE time <= ?", $Ftm_stat);
%p or Error('За запрошенный день нет статистики');
$Ftm_stat = $p{t};
$url->{tm_stat} = $Ftm_stat if defined ses::input('tm_stat');

my $Ffullday = ses::input_int('fullday');
$url->{fullday} = $Ffullday || undef;

my $Fuid = ses::input_int('uid');
if( $Fuid )
{
    $url->{uid} = $Fuid;
    my $info = Get_usr_info($Fuid);
    $info->{full_info} ||= "Для клиента id = $Fuid";
    push @ToRight, MessageWideBox( $info->{full_info} );
}


my $sql;
my $tbl = tbl->new(-class=>'td_wide pretty');
my $usr_field = $Fusr_field eq 'ALL'? 'id' : $Fusr_field;
if( $Fdetail )
{
    # Детализация среза
    $sql_where .= " AND t.uid = $Fuid" if $Fuid;
    # За сутки ограничим количество строк, иначе затупит надолго
    my $sql_inner = $Ffullday? "LIMIT 100000" : "WHERE time = $Ftm_stat";
    $sql = [
        "SELECT t.uid, t.time, t.bytes, t.direction, t.port, t.proto, t.class, INET_NTOA(uip) AS uip, INET_NTOA(ip) AS ip, u.$usr_field ".
        "FROM (SELECT * FROM $traf_tbl_name $sql_inner) AS t ".
        "LEFT JOIN fullusers u ON t.uid = u.id WHERE 1 $sql_where ORDER BY t.bytes DESC",
    ];
    $tbl->add('head', 'rlclrcrl', @lang::mTraf_tbl_head_detail);

}
 else
{
    $sql_where .= " AND uid = $Fuid" if $Fuid;
    $sql_where .= " AND time = $Ftm_stat" if ! $Ffullday;
    $sql = [
        "SELECT t.uid, t.traf_in, t.traf_out, u.$usr_field ".
        "FROM (SELECT SUM(`in`) AS traf_in, SUM(`out`) AS traf_out, uid FROM $traf_tbl_name WHERE 1 $sql_where GROUP BY uid) AS t ".
        "LEFT JOIN fullusers u ON t.uid = u.id ORDER BY traf_in DESC",
    ];
    $tbl->add('head', 'rrrl', @lang::mTraf_tbl_head);
}


# Предыдущая отметка времени даст период текущего среза. Если не получим, то период в 0 сек корректен, будут выводится `?`
my $url_prev_time;
my $period = 0;
my %p = Db->line("SELECT time FROM $traf_tbl_name WHERE time < ? ORDER BY time DESC LIMIT 1", $Ftm_stat);
if( %p )
{
    my $prev_time = $p{time};
    $period = $Ftm_stat - $prev_time;
    # Если вывод за сутки, то скорость отобразить не получится, 0й период приведет к выводу `?` - норм
    $period = 0 if $Ffullday;
    $url_prev_time = $url->a( [the_hour($prev_time).'&larr;'], tm_stat=>$prev_time );
}
# Следующая отметка времени
my %p = Db->line("SELECT time FROM $traf_tbl_name WHERE time > ? ORDER BY time LIMIT 1", $Ftm_stat);
my $url_next_time = %p? $url->a( ['&rarr;'.the_hour($p{time})], tm_stat=>$p{time} ) : '';

# Если выборка за целые сутки, то скорость не можем показать, покажем в байтах
my $traf_ed = $Ffullday? ' B00': $ses::cookie->{ed_log};

my($sql, $page_buttons, $rows, $db) = Show_navigate_list($sql, ses::input_int('start'), 30, $url);
my $usr_url;
while( my %p = $db->line )
{
    my $uid = $p{uid} or next; # служебная запись
    if( $Fuid )
    {
        $usr_url = '';
    }
     elsif( $Fusr_field eq 'ALL' )
    {
        $usr_url = [ Get_usr_info($uid)->{full_info} ];
    }
     else
    {
        $usr_url = [ url->a($p{$Fusr_field}, -ajax=>1, a=>'ajUserInfo', uid=>$uid) ];
    }
    if( $Fdetail )
    {
        my $domid = v::get_uniq_id();
        my $url_resolve = [ _("[div id=$domid]",
            url->a($p{ip}, -ajax=>1, a=>'ajResolve', ip=>$p{ip}, domid=>$domid)
        ) ];
        $tbl->add('*', 'rlclrcrl',
            $usr_url,
            $p{uip},
            [ $p{direction}==1? '&rarr;' : '&larr;' ],
            $url_resolve,
            $p{port},
            $cfg::_ip_proto->{$p{proto}} || $p{proto},
            [ Print_traf($p{bytes}, $traf_ed, $period) ],
            $cfg::trafname{$p{class}},
        );
    }
     else
    {
        $tbl->add('*', 'rrrl',
            $usr_url,
            [ Print_traf($p{traf_in},  $traf_ed, $period) ],
            [ Print_traf($p{traf_out}, $traf_ed, $period) ],
            [ $url->a('дет', uid=>$p{uid}, detail=>1) ],
        );
    }
}

Show Center $tbl->show;
Doc->template('base')->{top_lines} .= _('[div h_center txtpadding]', $page_buttons) if $page_buttons;

Doc->template('top_block')->{add_info} = _('[] назад', the_hh_mm($ses::t - $Ftm_stat));
if( !$Ffullday )
{
    unshift @ToLeft, WideBox( 
        msg => _('[span nav] [span bold] [span nav]',
            $url_prev_time,
            the_hour($Ftm_stat),
            $url_next_time
        )
    );
}

my $menu = '';

if( $Fuid )
{
    $menu .= $url->a( 'Все клиенты', uid => undef );
}
 else
{   # Меню полей таблицы fullusers (что выводить: фио/логин/id)
    foreach my $field( keys %$cfg::_fullusers_fields )
    {
        $menu .= $url->a( $lang::fullusers_fields_name->{$field} || $field, usr_field=>$field, -active=>($field eq $Fusr_field) );
    }
}

$menu .= '<hr>';

$menu .= $url->a( 'Детализация', detail => !$Fdetail, -class=>(!!$Fdetail && 'active') );
$menu .= $url->a( 'По всем направлениям', traf_cls=>undef, -class=>(!!$Ftraf_cls || 'active') );
foreach my $traf_cls( 1..4)
{
    my $active = $traf_cls == $Ftraf_cls && 'active';
    $menu .= $url->a( $cfg::trafname{$traf_cls}, traf_cls=>$traf_cls, -class=>$active );
}

$menu .= '<hr>';
$menu .= $url->a( 'За сутки', fullday => !$Ffullday, -class=>(!!$Ffullday && 'active') );

push @ToRight, Menu($menu);

push @ToRight, MessageWideBox( Get_list_of_stat_days($traf_tbl_type, $url, $Ftm_stat) );

if( !$Ffullday )
{   # за сутки показываем всегда в байтах, поэтому не выводим строку выбора единиц измерения:
    Doc->template('top_block')->{urls_ed} = Set_traf_ed_line('ed_log', $url, [ map{ $_->[4] } @lang::Ed ]);
}

1;
