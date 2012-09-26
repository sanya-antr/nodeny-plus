#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package noserver::nofire;
use strict;
use Debug;
use Exporter 'import';

our @EXPORT = qw( fw_flush fw_set fw_usr_on fw_usr_off fw_run fw_net_add fw_net_del fw_add_in fw_add_out );

=head

Скрипт управляет созданием правил в ipfw разрешающих/запрещающих/shape-щих трафик клиентов.
Можно менять, при этом автор и техподдержка очень просят ДОБАВЛЯТЬ ВАШИ копирайты к шапке.

Входящий/исходящий трафик рассматривается по отношению к клиенту.

Принцип работы.

В фаерволе выделяются 2 окна, в которые данные скрипт динамически добавляет/удаляет правила.
Первое окно (с меньшими номерами правил) предназначено для фильтрации исходящих (от клиента) пакетов,
второе - для входящих.

При старте все правила в обоих окнах удаляются (см. sub fw_flush)

noserver.pl получает из БД список всех сетей всех направлений и вызывает fw_net_add, которая
для каждого направления выделяет 3 отдельных таблицы:

  10 + № направления: список сетей данного направления
  20 + № направления: список ip абонентов с номерами пайпов для шейпа исходящего трафика
  30 + № направления: список ip абонентов с номерами пайпов для шейпа входящего трафика

Например, для 4го направления в первом окне формируется примерно следующее:

 aaaa skipto cccc ip from table(24) to table(14)
 ....
 bbbb deny ip from any to any
 cccc pipe tablearg ip from table(24) to any
 ....
 dddd deny ip from any to any

 Допустим, направление 4 - это локальные ресурсы (сеть 10.1.2.0/24). Они будут занесены в таблицу 14
 В таблицу 24 динамически (см. sub fw_usr_on) будут добавляться ip клиентов, которым будет разрешен доступ в интернет,
 при этом в качестве аргумента будет номер pipe, режущий трафик согласно тарифа.

 Обратите внимание, что в тарифе задается общая скорость, т.е. шейпы в направления 2,3 и 4 отключены.
 Включаются шейпы дополнительными модулями, которые декодируют поле `скрипты` тарифа и могут дать
 указание, например, выставить 2000 байт/сек на направление 2 клиенту с id = 10:
 $M->{users}{10}{speed_in2} = 2000;

=cut

$cfg::fw_cmd ||= '/sbin/ipfw -q ';

# Если у клиента в пакете или в личных данных не указаны скорости, то будут выставлены стандартные.
# Стандартные указываются в конфиге сателлита, если там не указаны, то принимает такие:

$cfg::speed_in  ||= 100000;  # скорость к клиенту, кбит
$cfg::speed_out ||= 10000;  # скорость от клиента, кбит

$cfg::ipfw_tbl_start = int($cfg::ipfw_tbl_start) || 10;

# окно правил, в котором будет осуществляться фильтрация пакетов от клиентов
$cfg::ipfw_num_out_start ||= 5000;
$cfg::ipfw_num_out_end   ||= 32000;

$cfg::ipfw_num_in_start  ||= 33000;
$cfg::ipfw_num_in_end    ||= 60000;

my $Pipes = {};
my $Tbl_to_fwnum = {};

sub fw_set
{
 my($M, $rule) = @_;
 $M->{fw}{rules} .= $rule."\n";
}

sub fw_add_in
{
 my($M, $rule) = @_;
 $M->{fw}{rules} .= 'add '.$M->{fw}{cursor_in}++.' '.$rule."\n";
}

sub fw_add_out
{
 my($M, $rule) = @_;
 $M->{fw}{rules} .= 'add '.$M->{fw}{cursor_out}++.' '.$rule."\n";
}

sub fw_run
{
 my($M) = @_;
 $M->{fw}{rules} eq '' && return;
 if( $cfg::verbose )
 {
    debug($M->{fw}{rules});
    $M->{fw}{rules} = '';
    return;
 }
 my $file_ipfw = $cfg::dir_log.'ipfw_'.$M->Time;
 open(F,">>$file_ipfw") or return;
 print F $M->{fw}{rules};
 close (F);
 $M->{fw}{rules} = '';
 system("$cfg::fw_cmd $file_ipfw");
 unlink $file_ipfw;
}

sub fw_flush
{
 # 1. Удаляет из фаервола все правила в диапазонах
 #      $cfg::ipfw_num_out_start .. $cfg::ipfw_num_out_end
 #      $cfg::ipfw_num_in_start  .. $cfg::ipfw_num_in_end
 #    т.е. освобождет 2 окна, в которых будут формироваться правила фильтрации пакетов клиентов
 # 2. Формирует общие правила в созданных окнах

 my($M) = @_;
 
 $Pipes = {
    refs => {}, # счетчик использования пайпов, как только на пайп перестают ссылаться - он удаляется
    uid  => {}, # какой клиент какой pipe использует
 };

 $M->{fw}{rules} = '';

 my $num = 0;
 # удалим все правила, попадающие в управляемые окна
 foreach( split /\n/, `$cfg::fw_cmd list` )
 {
    /^\s*(\d+)/ or next;
    $num == $1 && next; # на правиле может быть несколько записей
    $num = $1;
    if( ($num >= $cfg::ipfw_num_out_start && $num <= $cfg::ipfw_num_out_end) ||
        ($num >= $cfg::ipfw_num_in_start  && $num <= $cfg::ipfw_num_in_end) )
    {
        $M->fw_set("delete $1");
    }
 }

 $M->{fw}{cursor_in}   = $cfg::ipfw_num_in_start;
 $M->{fw}{cursor_out}  = $cfg::ipfw_num_out_start;
 $M->{fw}{cursor_in2}  = int( ($cfg::ipfw_num_in_start + $cfg::ipfw_num_in_end)/2 );
 $M->{fw}{cursor_out2} = int( ($cfg::ipfw_num_out_start + $cfg::ipfw_num_out_end)/2 );

 # Редирект на заглушку. Если не используется - закомментировать строку
 $M->{fw}{rules} .= 'add '.$M->{fw}{cursor_out2}++." fwd 127.0.0.1, 8080 tcp from any to any 80\n";
 $M->{fw}{rules} .= 'add '.$M->{fw}{cursor_out2}++." deny ip from any to any\n";
 $M->{fw}{rules} .= 'add '.$M->{fw}{cursor_in2}++." deny ip from any to any\n";
 $M->{fw}{rules} .= 'add '.$cfg::ipfw_num_in_end." deny ip from any to any\n";
 $M->{fw}{rules} .= 'add '.$cfg::ipfw_num_out_end." deny ip from any to any\n";

 # При создании правила, сюда будет записываться правило для удаления созданного
 $M->{fw}{remove} = {};
}


# По id клиента генерирует номер pipe
# Будут начинаться с 1000 (до этого зарезервированы), умножение на 10 - это 10 (с резервом) пайпов под каждый ip
sub _fw_pipe_by_uid
{
 my($uid) = @_;
 my $fw_num = $uid*10 + 1000;
 if( $fw_num > 65500 )
 {
    # Сообщение в лог не чаще 600 секунд: Protect_time(время, id_защиты)
    noserver->Protect_time(600, 'fw_many_uids') && 
        tolog("Нет свободных pipe ipfw т.к. слишком много авторизованных клиентов");
    $fw_num = 65500;
 }
 return $fw_num;
}


sub fw_net_add
{
 my($M, $class, $net) = @_;
 debug("Добавление в фаервол сети $net направления $class");
 my $net_tbl = $class + $cfg::ipfw_tbl_start;

 if( ! $Tbl_to_fwnum->{$net_tbl} )
 {
    my $cur_in  = $M->{fw}{cursor_in};
    my $cur_out = $M->{fw}{cursor_out};
    $Tbl_to_fwnum->{$net_tbl} = [ $cur_in++, $cur_out++ ];

    $M->fw_set("table $net_tbl flush");

    my $usr_tbl = $net_tbl + 10;
    $M->fw_set("table $usr_tbl flush");
    $M->fw_add_out("skipto $M->{fw}{cursor_out2} ip from table($usr_tbl) to table($net_tbl)");
    $M->{fw}{rules} .= 'add '.$M->{fw}{cursor_out2}++." pipe tablearg ip from table($usr_tbl) to any\n";

    my $usr_tbl = $net_tbl + 20;
    $M->fw_set("table $usr_tbl flush");
    $M->fw_add_in("skipto $M->{fw}{cursor_in2} ip from table($net_tbl) to table($usr_tbl)");
    $M->{fw}{rules} .= 'add '.$M->{fw}{cursor_in2}++." pipe tablearg ip from any to table($usr_tbl)\n";
 }
 $M->fw_set("table $net_tbl add $net");
}

sub fw_net_del
{
 my($M, $preset, $class, $net) = @_;
 debug("Удаление из фаервола сети $net направления $class");
 my $tbl = $class + $cfg::ipfw_tbl_start;
 $M->fw_set("table $tbl delete $net");
}

sub fw_usr_on
{
 my($M, $uid) = @_;
 my $usr = $M->{users}{$uid};
 my $ips = $usr->{ip};
 if( $cfg::verbose )
 {
    my $speed = int $usr->{speed_in1}/1000;
    debug("Fw On uid: $uid, ip: $ips, вх.скор: $speed КБит/с");
 }

 my $tbl_out = $cfg::ipfw_tbl_start + 11;
 my $tbl_in  = $cfg::ipfw_tbl_start + 21;
 my $pipe_out = _fw_pipe_by_uid($uid) + 1;
 my $pipe_in  = $pipe_out + 5;
 my $remove_rules = '';
 foreach my $i( 1..4 )
 {
    my($speed_in, $speed_out) = ($usr->{"speed_in$i"}, $usr->{"speed_out$i"});
    # если у направления не указана скорость - направление не шейпится (трафик попадает в пайп 1го направления)
    !$speed_in && $i>1 && next;

    $M->fw_set("pipe $pipe_out config bw ${speed_out}bit/s");
    $remove_rules .= "pipe $pipe_out config\n";
    $remove_rules .= "pipe $pipe_out delete\n";
    if( $speed_out )
    {
        $M->fw_set("pipe $pipe_in config bw ${speed_in}bit/s");
        $remove_rules .= "pipe $pipe_in config\n";
        $remove_rules .= "pipe $pipe_in delete\n";
    }else
    {   # не указана исходящая скорость - вход и выход в один pipe
        $pipe_in = $pipe_out;
    }
    foreach my $ip( split /,/, $ips )
    {
        $M->fw_set("table $tbl_in add $ip $pipe_in");
        $remove_rules .= "table $tbl_in delete $ip\n";
        $M->fw_set("table $tbl_out add $ip $pipe_out");
        $remove_rules .= "table $tbl_out delete $ip\n";
    }
 }
  continue
 {
    $pipe_out++;
    $pipe_in++;
    $tbl_out++;
    $tbl_in++;
 }
 $M->{fw}{remove}{$uid} = $remove_rules;
}

sub fw_usr_off
{
 my($M, $uid) = @_;
 $M->{fw}{rules} .= $M->{fw}{remove}{$uid};
 delete $M->{fw}{remove}{$uid};
}

1;
