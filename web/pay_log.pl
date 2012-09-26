#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use web::Pay;

sub go
{
 my($url) = @_;

 my $pay_types = [
    [ 'все'                 => 'p.category<>3'  ],
    [ 'финансовые'          => 'p.cash<>0'      ],
    [ 'нефинансовые'        => 'p.cash=0'       ],
    [ 'бонусы'              => 'p.category=2'   ],
    [ 'временные'           => 'p.category=3'   ],
    [ 'платежные системы'   => 'p.category=20'  ],
    [ 'карточки'            => 'p.category=99'  ],
    [ 'услуги'              => 'p.category=100' ],
 ];

 Adm->chk_privil_or_die('pay_show');

 my $Fstart = ses::input_int('start');

 # Если определен $ses::unikey, то значит некоторые данные переданы не через http, а через БД по этому ключу
 $url->{_unikey} = $ses::unikey if defined $ses::unikey;

 my $sql_where = '';
 my @sql_where = ();

 my @Info_block = ( Center(v::submit('Показать')) );

 # --- Фильтр по дате ---
 {
    foreach my $param( 
        [ 'start_date', ' AND p.time >= ?' ],
        [ 'end_date',   ' AND p.time < UNIX_TIMESTAMP(FROM_UNIXTIME(?)+INTERVAL 1 DAY)' ]
    ){
        my $d = ses::input($param->[0]);
        $d =~ s/ //g;
        $d or next;
        my($day,$mon,$year) = split /\./, $d;
        my $time;
        eval{ $time = timelocal(0,0,0,$day,$mon-1,$year) };
        $@ && next;
        $url->{$param->[0]} = $d;
        $sql_where .= $param->[1];
        push @sql_where, $time;
    }
    push @Info_block,
         'от '.v::input_t(name=>'start_date', value=>ses::input('start_date'), class=>'dateinput').
        ' до '.v::input_t(name=>'end_date', value=>ses::input('end_date'), class=>'dateinput');
 }

 my $one_client;
 # --- Для клиента/ов ---
 {
    # !! int т.к. попадает в sql !!
    my $uid = ref $ses::data && ref $ses::data->{ids}? join ',', map{ int $_ } @{$ses::data->{ids}} : ses::input_int('uid');
    $uid or last;
    if( $uid =~ /^\d+$/ )
    {   # для одного клиента
        $one_client = 1;
        my $info = Get_usr_info($uid);
        !Adm->chk_usr_grp($info->{grp}) && !Adm->chk_privil('SuperAdmin')
            && Error("Нет доступа к группе user id=$uid");
        push @Info_block, $info->{full_info} || "Клиента id=$uid";
        $url->{uid} = $uid;
        $sql_where .= ' AND p.mid=?';
        push @sql_where, $uid;
    }
     else
    {   # нескольких клиентов, доступ к группам не проверяем т.к. проверял модуль users
        push @Info_block, 'Клиентов по фильтру:<br>'.join('<br>',@{$ses::data->{info}});
        $sql_where .= " AND p.mid IN($uid)";
    }
 }

 # --- Типы платежей ---
 {
    my $pay_type = ses::input_int('pay_type');
    my @type_select = ();
    my $i = 0;
    foreach my $type( @$pay_types )
    {
        push @type_select, v::radio(
            name    => 'pay_type',
            value   => $i,
            checked => $i == $pay_type,
            label   => $type->[0],
        );
        $i == $pay_type or next;
        $one_client && !$pay_type && next;
        $sql_where .= ' AND '.$type->[1];
    }
     continue
    {
        $i++;
    }
    push @Info_block, join('<br>',@type_select);
    $url->{pay_type} = $pay_type if $pay_type;
 }

 my $info_block = join '<hr>', @Info_block;

 my $form = $url->form( -method=>'get', $info_block );

 ToRight MessageBox( $form );

 my $Sql = [ "SELECT p.*, u.fio, u.name FROM pays p LEFT JOIN users u ON p.mid = u.id WHERE 1 $sql_where ORDER BY time DESC", @sql_where ];

 my($sql, $page_buttons, $rows, $db) = Show_navigate_list($Sql, $Fstart, 15, $url);

 my $tbl = tbl->new( -class=>'td_wide td_medium fade_border pretty' );

 while( my %p = $db->line )
 {
    my $client = $p{mid}? url->a($p{mid}, a=>'ajUserInfo', uid=>$p{mid}, -ajax=>1) : '';
    my $decode = Pay::decode(\%p);

    my $cash = sprintf '%.2f', $p{cash};
    my $amt_pos = $cash>0 && $cash+0;
    my $amt_neg = $cash<0 && $cash+0;

    my $creator_id = $p{creator_id};
    my $creator = $p{creator} eq 'admin'? 'адм: '.Adm->get($creator_id)->login : 
                  $p{creator} eq 'user' ? 'клиент' :
                  $p{creator} eq 'other'? '' :
                  $p{creator};

    $tbl->add('*',[
        [ '',  'Клиент',        [ $client ] ],
        [ '',  "+ $cfg::gr",    $amt_pos ],
        [ '',  "- $cfg::gr",    $amt_neg ],
        [ '',  'Комментарий',   [ $decode->{for_adm} ] ],
        [ '',  'Автор',         [ $creator ] ],
        [ '',  'Время',         [ the_time($p{time}) ] ],
        [ 'h_center',   'Info', [ url->a('info', a=>'ajPayInfo', id=>$p{id}, -ajax=>1) ] ],
    ]);
 }

 Show Center( $page_buttons.$tbl->show.$page_buttons );
}

1;
