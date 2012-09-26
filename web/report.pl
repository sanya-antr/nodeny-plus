#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;
use vars qw( %F $Url $Adm );

chk_priv('fin_report');

require "$cfg::dir_web/paystype.pl";
require 'nomoney.pl';
TarifReload();

my $tm = localtime($ses::t);
my $cur_mon_time = timelocal(0,0,0,1,$tm->mon,$tm->year),

my $tm = localtime(int $F{time} || $ses::t);
my $Ftime = timelocal(0,0,0,1,$tm->mon,$tm->year);

my $sel_time = Select_mon_and_year( name=>'time', time=>$Ftime );

my @grp_list = map{ $_ => Ugrp->grp($_)->{name} } keys %{Ugrp->hash};
my $grp_select = $F{grp_list};
$grp_select =~ s|[^\d,]||g; # !!! т.к попадает в sql
my $grp_list = v::checkbox_list(
    name    => 'grp_list',
    list    => \@grp_list,
    checked => $grp_select,
    buttons => 1,
);

my $form = $Url->form( -method => 'get',
    _('[div][br][div h_center][br][div]', $sel_time, v::submit('Показать'), $grp_list)
);
ToLeft MessageBox( $form );

$grp_select or Error("Слева в меню отметьте группы, для которых необходимо сформировать отчет.");

if( $Ftime == $cur_mon_time  )
{   # Отчет за текущий месяц
    my %rep = ();
    my $db = Db->sql("SELECT * FROM fullusers WHERE grp IN($grp_select)");
    while( my %p = $db->line )
    {
        my %traf = map{ $_ => $p{$_} } grep{ /^(in|out)/ } keys %p;
        my $money_param = {
            paket     => $p{paket},
            paket3    => $p{paket3},
            service   => $p{srvs},
            start_day => $p{start_day},
            discount  => $p{discount},
            traf      => \%traf,
            mode_report=> 1,
        };
        my $money = Money($money_param)->{money};
        my $balance = $p{balance} - $money;
        $rep{users}++ if $money>0;
        $rep{money} += $money;
        if( $money > 0 && !$p{start_day} )
        {
            $rep{aged_users}++;
            $rep{aged_money} += $money;
        }
        if( $balance<0 )
        {
            $rep{users_neg}++; 
            $rep{balance_neg} -= $balance;
        }
        if( $balance>=0 )
        {
            $rep{users_pos}++;
            $rep{balance_pos} += $balance;
        }

        my $next_money_param = {
            paket     => $p{next_paket} || $p{paket},
            paket3    => $p{paket3},
            service   => $p{srvs},
            start_day => 0,
            discount  => $p{discount},
            traf      => {},
            mode_report=> 1,
        };
        my $next_money = Money($next_money_param)->{money};
        $balance -= $next_money;
        $rep{next_money} += $next_money;
        if( $balance<0 )
        {
            $rep{next_users_neg}++; 
            $rep{next_balance_neg} -= $balance;
            # задолженность кратная 5
            $_ = abs $balance;
            $rep{next_balance_neg5} += ($_>=5? int($_/5 + .999)*5 : 5);
        }
        if( $balance>=0 )
        {
            $rep{next_users_pos}++;
            $rep{next_balance_pos} += $balance;
        }
    }

    my $tbl = tbl->new(-class=>'width100 td_wide pretty');
    $tbl->add('head','3', 'Текущий месяц');
    $tbl->add('head','rrl', 'клиентов', ["&sum;&nbsp;$cfg::gr"], 'комментарий');
    $tbl->add('*','rrl',
        $rep{users},
        int $rep{money},
        "Сумма снятий за текущий месяц (только ненулевые тарифы)"
    );
    $rep{users}>0 && $tbl->add('*','rrl',
        '',
        sprintf("%.2f",$rep{money}/$rep{users}),
        "АРПУ по списаниям со счетов"
    );
    $tbl->add('*','rrl',
        $rep{aged_users},
        int $rep{aged_money},
        "Количество клиентов, у которых не нулевой тарифный план и которые подключены ранее текущего месяца, т.е стоимость тарифного плана учитывается за полный месяц"
    );
    $rep{aged_users}>0 && $tbl->add('*','rrl',
        '',
        sprintf("%.2f",$rep{aged_money}/$rep{aged_users}),
        "АРПУ по списаниям со счетов клиентов, которые работают полный месяц"
    );
    $tbl->add('head','3', '');
    $tbl->add('*','rrl',
        $rep{users_neg},
        int $rep{balance_neg},
        "Сумма отрицательных балансов, т.е. долг клиентов на данный момент."
    );
    $tbl->add('*','rrl',
        $rep{users_pos},
        int $rep{balance_pos},
        "Сумма остатков на балансах. Эти деньги `перейдут` на новый месяц в счет (части) абонплаты."
    );
    $tbl->add('head','3', 'Следующий месяц');
    $tbl->add('*','rrl',
        '',
        int $rep{next_money},
        "В следующем месяце с клиентов будет снята такая сумма. Учтены заказы на смену тарифных планов."
    );
    $rep{users}>0 && $tbl->add('*','rrl',
        '',
        sprintf("%.2f",$rep{next_money}/$rep{users}),
        "АРПУ по списаниям со счетов клиентов"
    );
    $tbl->add('*','rrl',
        $rep{next_users_neg},
        int $rep{next_balance_neg},
        "Долг клиентов, который возникнет при наступлении следующего месяца."
    );
    $tbl->add('*','rrl',
        '',
        int $rep{next_balance_neg5},
        "Если допустить, что клиенты будут погашать задолженность суммой кратной 5, то данный параметр приблизительно показывает сумму, которая будет внесена для оплаты следующего месяца."
    );
    $tbl->add('*','rrl',
        $rep{next_users_pos},
        int $rep{next_balance_pos},
        "Клиенты, у которых не будет долга при наступлении следующего месяца, сумма балансов (т.е эти деньги перенесутся на последующий месяц, через один от текущего)"
    );
    Show $tbl->show;
}

return 1;

no strict;

$time1=timelocal(0,0,0,1,$Fmon-1,$Fyear); # начало месяца
if ($Fmon<12) {$mon=$Fmon; $year=$Fyear} else {$mon=0; $year=$Fyear+1}
$time2=timelocal(0,0,0,1,$mon,$year); # начало следущего месяца

$where_time="WHERE p.time>=$time1 AND p.time<$time2";


1;
