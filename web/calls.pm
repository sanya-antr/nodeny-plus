#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

use Time::localtime;
use Time::Local;
use Digest::MD5 qw( md5_base64 );
use base qw( Exporter );

use Db;
use nod::tmpl;

$cfg::cookie_name_for_ses = 'noses';        # имя куки для сессии
$cfg::max_byte_upload     = 44000;          # максимальное количество байт, которые мы можем принять по методу post
$cfg::web_session_ttl     = 2*60*60;        # время жизни сессии при отсутствии активности, секунд

our @EXPORT = qw( _ Error Error_ Show ToTop ToLeft ToRight Menu Center MessageBox MessageWideBox );

require $cfg::main_config;

$cfg::Db_server ||= 'localhost';
$cfg::Db_name   ||= 'bill';

Db->new(
    host    => $cfg::Db_server,
    user    => $cfg::Db_user,
    pass    => $cfg::Db_pw,
    db      => $cfg::Db_name,
    timeout => $cfg::Db_connect_timeout,
    tries   => 2, # 2 попытки коннекта с интервалом в секунду 
    global  => 1, # создать глобальный объект Db, чтобы можно было вызывать без объекта: Db->sql()
);

my %p = Db->line("SELECT *,UNIX_TIMESTAMP() AS t FROM config ORDER BY time DESC LIMIT 1");
Db->is_connected or die 'No DB connection';
%p or die 'No config in DB';

$ses::t = $p{t};
$cfg::config = $p{data};

eval "
    no strict;
    $cfg::config;
    use strict;
";

$cfg::img_dir =~ s|/$||;

$cfg::tmpl_dir = "$cfg::dir_web/tmpl/";

$cfg::kb = $cfg::kb + 0 || 1000;
$cfg::mb = $cfg::kb * $cfg::kb;

$cfg::Lang = uc $cfg::Lang || 'RU';
$cfg::Lang_file = "$cfg::dir_web/lang/$cfg::Lang.pl";

# Загрузим lang файл, указанный в настройках. Если не получится, то RU
eval{ require $cfg::Lang_file };
if( $@ )
{
    my $err = $@;
    Require_web_mod('lang/RU') && die $err;
    debug('error', $err);
}

%cfg::trafname = (
    0 => $lang::lbl_default_name_traf.' 0',
    1 => $cfg::trafname1 || $lang::lbl_default_name_traf.' 1',
    2 => $cfg::trafname2 || $lang::lbl_default_name_traf.' 2',
    3 => $cfg::trafname3 || $lang::lbl_default_name_traf.' 3',
    4 => $cfg::trafname4 || $lang::lbl_default_name_traf.' 4',
);

my $tt = localtime($ses::t);
$ses::day_now  = $tt->mday;
$ses::mon_now  = $tt->mon+1;
$ses::year_now = $tt->year+1900;
$ses::time_now = the_time($ses::t);

$ses::ip = $ENV{HTTP_X_REAL_IP} || $ENV{REMOTE_ADDR};
$ses::ip =~ s|[^\d\.]||g;

$ses::server = $ENV{SERVER_NAME};
$ses::server =~ s|/$||;
$ses::script = $ENV{SCRIPT_NAME};
$ses::script =~ s/'//g && die '$ENV{SCRIPT_NAME} error';

$ses::http_prefix = $ENV{HTTPS}? 'https://' : 'http://';

$ses::script_url = $ses::http_prefix.$ses::server.$ses::script;

if( $cfg::img_dir !~ /^http/ )
{
    $cfg::img_url = $ses::http_prefix.$ses::server.($cfg::img_dir !~ m|^/| && '/').$cfg::img_dir;
}

$cfg::err_pic = "$cfg::img_dir/err.png";

# Текстовые синонимы привилегий (не все!)
%cfg::pr_def = (
  1 => 'on',
  2 => 'Admin',
  3 => 'SuperAdmin',
 11 => 'edt_old_pays',
 12 => 'edt_foreign_pays',
 14 => 'events',
 17 => 'report',
 20 => 'cards',
 27 => 'edt_category_pays',
 30 => 'pay_show',
 31 => 'event_show',
 50 => 'pay_cash',
 51 => 'pay_bonus',
 52 => 'pay_tmp',
 55 => 'msg_create',
 60 => 'edt_pays',
 61 => 'show_usr_pass',
 69 => 'usr_create',
 70 => 'edt_usr',
 94 => 'topology',
 95 => 'edt_topology',
100 => 'usr_stat_page',
);

package Doc;

my $Doc = {
    'base' => {
        'script_url'        => $ses::script_url,
        'main_v_align'      => 'top',
        'css_left_block'    => '',
        'css_right_block'   => '',
    }
};

bless $Doc;

sub template
{
    my(undef, $template) = @_;
    $Doc->{$template} ||= {};
    return $Doc->{$template};
}

package main;

our %F = ();

{
    my $debug = {};
    # Каждую присланную переменную обрезаем в debug-е по столько символов:
    my $show_len = 300;
    my $query = '';
    sub _show_query
    {
        my $str = substr ${$_[0]}, 0, $show_len;
        $str =~ s/(.{101})/$1\n/g;
        length ${$_[0]} <= $show_len && return $str;
        return{ "first $show_len symbols"=>$str };
    }

    if( $ENV{REQUEST_METHOD} eq 'POST' )
    {
        my $len = $ENV{CONTENT_LENGTH};
        $len > $cfg::max_byte_upload && Error("Превышение допустимой длины запроса: $len > $cfg::max_byte_upload (байт)");
        read(STDIN, $query, $len);
        debug('POST data:', _show_query(\$query) );
    }

    my $query_get = $ENV{QUERY_STRING};

    if( length $query_get )
    {
        debug('GET data:', _show_query(\$query_get) );
        $query .= ($query && '&').$query_get;
    }

    # Рассматриваем запрос как набор байтов, а не utf8
    utf8::is_utf8($query) && utf8::encode($query);

    $ses::query = $query;
    my @pairs = split /&/,$query;
    my %multi = ();
    foreach my $pair( @pairs )
    {
        my($name,$value) = split /=/,$pair;
        $multi{$value} = 1 if $name eq '__multi';
    }
    foreach my $pair( @pairs )
    {
        my($name,$value) = split /=/,$pair;
        $name =~ tr/+/ /;
        $name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
        $value=~ tr/+/ /;
        $value=~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
        $_ = $value;
        # искажен utf-8?
        utf8::decode($_) or next;
        if( $multi{$name} && $F{$name} ne '' )
        {
            $F{$name} .= ','.$value;
        }
         else
        {
            $F{$name} = $value;
        }
        $debug->{$name} = substr $F{$name},0,$show_len;
    }
    keys %$debug && debug('pre',$debug);
}

$ses::input_orig = \%F;

$ses::cookie = {};

foreach( split/;/,$ENV{HTTP_COOKIE} )
{
   my($name,$value) = split /=/,$_;
   $name =~ s/^ +//;
   $ses::cookie->{$name} = $value;
}

keys %{$ses::cookie} && debug('pre', 'Текущие cookies: ', $ses::cookie);

$ses::set_cookie = {};
foreach my $key( grep{ /^set_/ } keys %F )
{
    my $val = $F{$key};
    $key =~ s|^set_||;
    $key =~ s|^ +||;
    $ses::cookie->{$key} = $val;
    $ses::set_cookie->{$key} = $val;
    delete $F{$key};
}

$ses::auth = { auth=>0, uid=>0, role=>'', adm=>{} };

{
    my $ttl = 0;
    my $ses = $ses::cookie->{$cfg::cookie_name_for_ses};
    if( $ses )
    {  # в куках передан id сессии
        my %p = Db->line(
            "SELECT * FROM websessions s LEFT JOIN admin a ON (s.uid=a.id AND s.role='admin') WHERE BINARY ses=? LIMIT 1", $ses
        );
        if( %p )
        {
            $ttl = $p{expire} - $ses::t;
            $ttl = 0 if $ttl<0;
            if( $ttl )
            {
                $ses::auth = {
                    auth => 1,
                    uid  => $p{uid},
                    role => $p{role},
                    ses  => $ses,
                    adm  => \%p,
                };
                debug("Сессия `$ses` существует, uid: $p{uid}, role: $p{role}");
            }
             else
            {
                debug("Сессия `$ses` существует, но устарела.");
            }
        }
         elsif( Db->rows < 0 )
        {
            die '[[[ repair tables ]]]';
        }
         else
        {
            debug("Сессии `$ses` нет в БД. Скорее всего удалена по таймауту.");
        }
    }
     else
    {
        debug("Сессия через cookie `$cfg::cookie_name_for_ses` не передана.");
    }


    !$ses::ajax && $ttl &&
        Db->do("UPDATE websessions SET expire=UNIX_TIMESTAMP()+? WHERE BINARY ses=? LIMIT 1", $cfg::web_session_ttl, $ses);

    # --- в $F{_unikey} ключ к данным, которые передаются модулю с именем в поле module
    {
        $F{_unikey} or last;
        $ses::unikey = $F{_unikey};
        my %p = Db->line("SELECT * FROM webses_data WHERE BINARY unikey=? LIMIT 1", $ses::unikey);
        if( !%p )
        {
            %F = ();
            Db->ok && debug('warn', 'Данные по ключу _unikey не найдены. Возможно были удалены по времени');
            last;
        }
        my $VAR1;
        eval $p{data};
        if( $@ )
        {
            %F = ();
            debug('warn', "Ошибка парсинга данных: $@");
            last;
        }
        $ses::data = $VAR1;
        $ses::data_created = $p{created};
        debug('pre', "Данные по unikey `$ses::unikey`:", $ses::data) if length $p{data}<5000;
        delete $F{_unikey}; # не позже т.к. в самих данных может быть _unikey
        if( ref $ses::data->{-input} eq 'HASH' )
        {
            map{ $F{$_} = $ses::data->{-input}{$_} } grep{ ! defined $F{$_} } keys %{$ses::data->{-input}};
        }
        $F{a} = $p{module};
    }
}

$ses::input = \%F;

$ses::subs = {
    exit    => [],
    render  => ($ses::ajax? \&ajRender : \&Render),
};

# -------------------------------------------------------------------------------------------------------

sub sub_zero {}

sub _set_cookie_str
{
    my $cookie = '';
    if( keys %$ses::set_cookie )
    {
        foreach my $key( keys %$ses::set_cookie )
        {
            my $val = $ses::set_cookie->{$key};
            my $expire = $val ne ''? 'Thu,31-Dec-2020' : 'Thu,31-Dec-2020';#'Thu,28-Dec-2000';
            $cookie .= "Set-Cookie: $key=$val;path=/;expires=$expire 00:00:00 GMT;";
        }
        debug('pre', $cookie);
        $cookie  .= "\n";
    }
    return $cookie;
}

sub remove_session
{
    Db->do("DELETE FROM websessions WHERE uid=? AND role=?", $ses::auth->{uid}, $ses::auth->{role});
    url->redirect(a=>'', @_);
}

sub ajError
{
    my $err = join ' ', @_;
    debug('error', $err);
    Exit();
}

sub ajRender
{
    push @$ses::cmd, {
        id     => 'debug',
        data   => Debug->show,
        action => 'insert',
    };
    eval 'use JSON';
    $@ && die $@;
    print join( "\n",
          'Content-type: text/html; charset=utf-8',
          'Cache-Control: no-store, no-cache, must-revalidate'
        ).
         "\n\n".
         to_json($ses::cmd);
    exit;
}

sub Render
{
    my $cookie = _set_cookie_str();

    if( $ses::debug )
    {
        Doc->template('base')->{debug} = Debug->show;
        Doc->template('base')->{debug_errors} = Debug->errors || '';
    }
    my $html = tmpl('base', %{Doc->template('base')});

    foreach my $sub( @{$ses::subs->{end}} ) { &{ $sub } }

    print "Content-type: text/html\n".$cookie."\n";
    print $html;
    exit;
}

sub Exit
{
    {   # Сообщение в топ
        defined $ses::data->{-made} or last;
        my $m = $ses::data->{-made};
        # Сообщение выводим только, если оно было создано менее 15 сек назад
        my $msg_expire = $ses::t - ($ses::debug? 600:15);
        $m->{created} && $m->{created} < $msg_expire && last;
        # Не фильтруем т.к. сообщение передается через базу, т.е доверенное
        my $msg = _($m->{error}? '[div top_msg_error]' : '[div]', $m->{msg});
        Doc->template('top_block')->{made_msg} .= $msg ;
    }

    if( ref $ses::cmd eq 'ARRAY' && scalar @$ses::cmd )
    {
        foreach my $p( @$ses::cmd )
        {
            if( $p->{type} eq 'js' )
            {
                Doc->template('base')->{document_ready} .= $p->{data}.';';
                next;
            }
            if( !$p->{type} && $p->{id} ne '' )
            {
                my $to_dom_id = $p->{id};
                my $from_dom_id = v::get_uniq_id();
                Doc->template('base')->{buffer} .= "<div id='$from_dom_id'>$p->{data}</div>";
                my $action = $p->{action} eq 'add'? 'append' : $p->{action} eq 'insert'? 'prepend' : 'html';
                Doc->template('base')->{document_ready} .= " \$('#$to_dom_id').$action(\$('#$from_dom_id'));";
            }
        }
    }
    foreach my $sub( @{$ses::subs->{exit}} ) { &{ $sub } }

    &{ $ses::subs->{render} };
}

sub tmpl
{
    my $tmpl_name = shift;
    return nod::tmpl::render(ref $tmpl_name? $tmpl_name : $cfg::tmpl_dir.$tmpl_name.'.html', @_);
}

# Преобразует число к виду '12 345 678'
sub split_n
{
 local $_=shift;
 1 while s/^([-+]?\d+)(\d{3})/$1 $2/;
 return($_);
}

sub lc_rus
{
 local $_ = shift;
 utf8::decode($_);
 $_ = lc $_;
 utf8::encode($_);
 return $_;
}

sub translit
{
 local $_;
 my $str = shift;
 utf8::decode($str);
 return join '', map{ utf8::encode($_), $lang::tanslit{$_} || $_ } split //, $str;
}

sub ToTop
{
 Doc->template('base')->{top_lines} .= _('[div top_msg h_center]', "@_" );
}

sub ToLeft
{
 Doc->template('base')->{left_block} .= join '<p></p>', @_;
}

sub ToRight
{
 Doc->template('base')->{right_block} .= join '<p></p>', @_;
}

sub Show
{
 Doc->template('base')->{main_block} .= join '<p></p>', @_;
}

sub Box
{
 return tmpl( 'box', @_ );
}

sub WideBox
{
 return Box( wide=>1, @_ );
}

sub MessageBox
{
 return Box( msg=>$_[0] );
}

sub MessageWideBox
{
 return Box( msg=>$_[0], wide=>1 );
}

# --- Вывод окна с ошибкой ---

sub ErrorMess
{
 my($msg) = @_;
 Show tmpl('box',
    css_class => 'big boxpddng',
    msg => tmpl('msg', pic=>$cfg::err_pic, msg=>$msg)
 );
}

# --- Вывод окна с ошибкой и выход ---

sub Error
{
 my $err = join ' ', @_;
 $ses::ajax && ajError($err);
 Doc->template('base')->{main_v_align} = 'middle';
 ErrorMess( $err );
 Exit();
}

sub Error_
{
 Error( _(@_) );
}


sub Menu
{
 return Box( msg=>(join '',@_), css_class=>'navmenu', wide=>1 );
}

sub Center
{
 return _('[div align_center]', "@_");
}

sub ajModal_window
{
 push @$ses::cmd, {
    id   => 'modal_window',
    data => join('', @_),
 };
 return 1;
}

sub _
{
 local $_;
 my($a, $f, @f);
 my @b = split /\[/,shift @_;
 my $out = shift @b;
 while( $a = shift @b )
 {
    $f = '';
    $a =~ s|^(.*)]|| or next;

    if($1 eq 'br') { $f.='<br>';         next }
    if($1 eq 'br2'){ $f.='<br><br>';     next }
    if($1 eq 'br3'){ $f.='<br><br><br>'; next }

    @f = split /\|/, $1;
    $f = shift @_;
    foreach( @f )
    {
        if($_ eq 'bold')  { $f = "<b>$f</b>";   next }
        if($_ eq 'commas'){ $f = "«$f»";        next }
        if($_ eq 'trim')  { $f = v::trim($f);   next }
        if($_ eq 'filtr') { $f = v::filtr($f);  next }
        my($tag,$param) = split / +/, $_, 2;
        if( defined $param )
        {
            $param = " class='$param'" if $param !~ s|([^=]+)=(.+)| $1='$2'|;
        }
        $f = "<$tag$param>$f</$tag>";
    }
 }
  continue
 {
    $out .= $f.$a;
 }
 return $out;
}

sub Del_Sort_Prefix
{
  local $_ = shift;
  s|^\[\d+\]||;
  $_;
}

# Время в виде dd.mm.gg hh:mm
sub the_time
{
 my $t = localtime(shift);
 return sprintf("%02d.%02d.%04d %02d:%02d", $t->mday,$t->mon+1,$t->year+1900,$t->hour,$t->min);
}

# Время в виде hh:mm
sub the_hour
{
 my $t = localtime(shift);
 return sprintf("%02d:%02d", $t->hour,$t->min);
}

# Время в виде dd.mm.gg hh:mm или hh:mm если день равен текущему
# Вход:
#  0 - время
#  1 - если установлен и день = текущему, то вернет `сегодня в hh:mm`
sub the_short_time
{
 my($time, $today) = @_;
 my $t1 = localtime($time);
 my $t2 = localtime($ses::t);
 return the_time($time) if !($t1->mday == $t2->mday && $t1->mon == $t2->mon && $t1->year == $t2->year);
 $t1 = the_hour($time);
 $today or return $t1;
 return "$lang::today в $t1";
}

# Время в виде dd.mm.gggg
sub the_date
{
 my $t = localtime(shift);
 return sprintf("%02d.%02d.%04d", $t->mday,$t->mon+1,$t->year+1900);
}

# Переводит период в секундах в вид чч:мм:сс
sub the_hh_mm_ss
{
 my($sec) = @_;
 return ($sec>59 && the_hh_mm($sec)).' '.($sec %  60).' сек';
}

# Переводит период в секундах в часы и минуты
sub the_hh_mm
{
 my $min = int($_[0]/60);
 my $res = '';
 if( $min >= 1440 )
 {
    $res .= int($min/1440).' дн. ';
    $min %= 1440;
 }
 if( $min >= 60 )
 {
    $res .= int($min/60).' час ';
    $min %= 60;
 }
 $res .= $min.' мин';
 return $res;
}

# Запись сообщения в лог
# Вход: сообщение
sub ToLog
{
 my $file = ">>$cfg::dir_home/logs/web.log";
 if( !open(LOG, $file) )
 {
    debug('error', "Не могу открыть на запись файл $file");
    return;
 }
 flock(LOG, 2);
 print LOG the_time(time)." @_\n";
 flock(LOG, 8);
 close(LOG);
}

# Формирования выпадающего списка с месяцами с заданным активным месяцем
# Вход: № месяца (1-12)
sub Set_mon_in_list
{
 my($mon) = @_;
 $mon ||= $ses::mon_now;
 return v::select(
    name     => 'mon',
    size     => 1,
    selected => $mon,
    options  => [ map{ $_ => $lang::month_names_for_day[$_] }( 1..12 ) ],
 );
}

# Формирования выпадающего списка с годами и selected делается запрошенный год
# Вход: год
sub Set_year_in_list
{
 my($year) = @_;
 $year ||= $ses::year_now;
 return v::select(
    name     => 'year',
    size     => 1,
    selected => $year,
    options  => [ map{ $_ => $_ }($ses::year_now-5..$ses::year_now) ],
 );
}

sub Select_mon_and_year
{
 my(%p) = @_;
 my $tm = localtime($p{time} || $ses::t);
 my $list = [];
 for( my $year = $ses::year_now; $year > $ses::year_now-6; $year-- )
 {
    for( my $mon = 12; $mon>0; $mon-- )
    {
        push @$list, timelocal(0,0,0,1,$mon-1,$year-1900) => $year.' '.$lang::month_names[$mon];
    }
 }
 return v::select(
    name     => $p{name},
    selected => timelocal(0,0,0,1,$tm->mon,$tm->year),
    options  => $list,
 );
}

# Возвращает максимальное число дней в запрошенном месяце
# Вход: месяц (1..12), год (0..ххх)
sub GetMaxDayInMonth
{
 return(eval{timelocal(0,0,0,31,$_[0]-1,$_[1])}?31:30) if $_[0]!=2; # это не февраль
 return(eval{timelocal(0,0,0,29,$_[0]-1,$_[1])}?29:28);
}

# Формирование кнопочек с сылками на страницы если результат sql-запроса не вмещается на страницу
# Вход:
#  0 - sql-запрос без команды LIMIT и обязательно начинающийся с SELECT, либо array ссылка
#       например, [ "SELECT * FROM users WHERE name LIKE = ?", '%test%']
#  1 - номер страницы, которая должна быть выведена
#  2 - максимальное количество записей на страницу
#  3 - объект url для кнопочек (в урл будут добавлены строки &start=xx)
#  4 - [объект Db] (не обязательный параметр)
# Выход:
#  0 - sql-запрос с проставленными LIMIT
#  1 - html с кнопочками
#  2 - общее количество строк в полном запросе
#  3 - указатель на $db c сформированным результатом, т.е для которого можно сделать $db->line

sub Show_navigate_list
{
 my($sql, $page, $on_page, $url, $db)=@_;
 $db ||= 'Db';
 $on_page = int $on_page;
 $on_page = 1 if $on_page<1;
 $page = int $page;
 $page = 0 if $page<0;

 my @param = ();
 if( ref $sql )
 {
    @param = @$sql;
    $sql = shift @param;
 }

 my $orig_sql = $sql;
 $sql .= " LIMIT ".($page*$on_page).",$on_page";
 my $run_sql = $sql;
 $run_sql =~ s/^\s*SELECT\s+/SELECT SQL_CALC_FOUND_ROWS /i;
 my $dbres = $db->sql($run_sql, @param); 
 my $rows = $dbres->{rows};
 $rows < 0 && return($sql, '', 0, $dbres);

 my $all_rows = $db->dbh->selectrow_array("SELECT FOUND_ROWS()");

 debug('Всего строк: ',$all_rows);

 if( !$rows )
 {
    $orig_sql .= " LIMIT 1";
    $dbres = $db->sql($orig_sql, @param);
    return(
        $orig_sql,
        $dbres->rows > 0? 'Необходимо вернуться на '.$url->a('страницу 1', start=>0, -class=>'nav') : '',
        $all_rows,
        $dbres,
    );
 }

 my $n = $all_rows;
 my @out = ();
 # если кол-во строк больше кол-ва которое можно выводить за раз, то сформируем навигацию
 if( $n > $on_page )
 {
    # если страниц немного - кнопочки сделаем широкими
    my $nav_class = $n/$on_page > 8? '' : ' nav_wide';

    # кнопка страницы №1 существует всегда
    push @out, $url->a('1', start=>0, -class=>($page? 'nav':'nav_active').$nav_class);

    # соседние кнопки для выбранной страницы оформляются в стиле nav, за ними для сужения вывода, кнопки
    # оформляются без стиля (как обычные гиперссылки). $steps указывает количество соседних кнопок в стиле nav.
    # чем больше номер выбранной страницы, тем $step меньше т.к. большое число на кнопке делает эту кнопку шире
    my $steps = $page<89? 9: $page<995? 5 : 2;

    my $i = 1; # начнем с кнопки для страницы №2
    $n -= $on_page;

    my $href;
    while( $n>0 )
    {
        my $len  = abs($i-$page); # количество кнопок от текущей до активной сраницы
        my $url0 = $url->new(start=>$i, -title=>($i+1));
        $url0->{-class}= !$len? 'nav_active'.$nav_class : $len<$steps? 'nav'.$nav_class : '';
        if( $len<29 )
        {
           $i++;
           $n -= $on_page;
           $href = $url0->a($len<$steps || $i%10==0 ? $i : '.');
        }
         else
        {
           $href = $url0->a(':');
           my $s = $len<109? 10 : $len<2000? 100 : 1000;
           $n -= $on_page * $s;
           $i += $s;
        }
        if( $n<0 && $len )
        {  # последняя кнопка и она не активна (не последняя страница выбрана)
           # Изменим номер последней страницы на действительно последнюю
           $i = int(($all_rows-1)/$on_page) + 1;
           $href = $url->a($i, 'start'=>$i-1, -class => 'nav'.$nav_class);
        }
        push @out, $href;
    }
 }
 my $out = join '', @out;
 return($sql, $out, $all_rows, $dbres);
}

sub Get_usr_info
{
    my($uid) = @_;
    {
        local $SIG{'__DIE__'} = {};
        eval "use web::Data";
        my $err = $@;
        if( $err )
        {
            debug('error', $err);
            return 0;
        }
    }
    my %p = Db->line("SELECT * FROM fullusers WHERE id=? LIMIT 1", $uid);
    Db->ok or return 0;
    %p or return {};
    $p{state_off} = $p{state} eq 'off';

    my $tbl = tbl->new( -row1=>'row3', -row2=>'row3' );
    $tbl->add('*','ll', $lang::fullusers_fields_name->{fio}, $p{fio});
    $tbl->add('*','ll', $lang::fullusers_fields_name->{name}, $p{name});
    $tbl->add('*','ll', $lang::lbl_inet_access, $p{state_off}? 'запрещен':'разрешен');
    $tbl->add('*','ll', $lang::fullusers_fields_name->{balance}, $p{balance}.' '.$cfg::gr);

    my $fields = Data->get_fields($uid);
    foreach my $alias( sort{ $fields->{$a}{order} <=> $fields->{$b}{order} } keys %$fields )
    {
        my $field = $fields->{$alias};
        $field->{flag}{q} or next; # не титульное поле
        my $value = $field->show( cmd=>'show' );
        $value eq '' && next;
        $tbl->add('*', 'll', $field->{title}, [$value]);
    }

    my $db = Db->sql("SELECT title FROM v_services WHERE uid=?", $uid);
    while( my %p = $db->line )
    {
        $tbl->add('*', 'll', 'Услуга', $p{title});
    }

    my $db = Db->sql("SELECT * FROM v_ips WHERE uid=? ORDER BY ip", $uid);
    while( my %p = $db->line )
    {
        my $ip = $p{ip};
        $ip .= ' (авт)' if $p{auth};
        $tbl->add('*', 'll', 'ip', $ip);
    }
    $tbl->add('', 'C', [ 
        url->a('Данные', a=>'user', uid=>$uid).
        ' / '.
        url->a('Меню', a=>'ajUserMenu', uid=>$uid, -ajax=>1)
    ]);
    $p{full_info} = _('[div usr_info_block]', $tbl->show);
    return \%p;
}


# Формирование списка дней на которые есть статистика трафика
# Вход:
#  1 - тип таблицы: 'Z' или 'X'
#  2 - url для сылок
#  3 - [любой time дня, на который показана статистика, будет выделен]
sub Get_list_of_stat_days
{
 my($tbl_type, $url, $sel_time) = @_;
 my $dbh = Db->dbh;
 my $sth = $dbh->prepare('SHOW TABLES');
 $sth->execute or return '';
 my $t = localtime(int $sel_time);
 # строка для сравнения с днем, который необходимо выделить
 $sel_time = $t->mday.'.'.$t->mon.'.'.$t->year;
 debug("SHOW TABLES (Таблиц: ".$sth->rows.")");
 my %days;
 while( my $p = $sth->fetchrow_arrayref )
 {
    $p->[0] =~ /^$tbl_type(\d\d\d\d)_(\d+)_(\d+)$/ or next;
    my $time = timelocal(59,59,23,$3,$2-1,$1); # конец дня
    $days{$time} = substr('0'.$3,-2,2).'.'.substr('0'.$2,-2,2).'.'.$1;
 }
 my $list_of_days = '';
 my $t1 = 0;
 my $t2 = 0;
 foreach my $time( sort {$b <=> $a} keys %days )
 {
    my $t = localtime($time);
    my $day  = $t->mday;
    my $mon  = $t->mon;
    my $year = $t->year;
    if( $t1 != $mon || $t2 != $year )
    {
       $t1 = $mon;
       $t2 = $year;
       $list_of_days .= _('[p]&nbsp;', $lang::month_names[$mon+1].' '.($year+1900).':');
    }

    $list_of_days .= $url->a( $day, tm_stat=>$time, -active=>$sel_time eq "$day.$mon.$year" );
    $list_of_days .= $day==11 || $day==21? '<br>&nbsp;' : ' ';
 }
 return $list_of_days;
}

# Возвращает трафик в указанных единицах измерения
# Вход:
#  0  - трафик
#  1  - единица измерения, либо индекс в @lang::Ed либо закодированная строка
# [2] - период времени
sub Print_traf
{
 my($traf, $ed, $time) = @_;
 $ed = 0 if ! defined $ed;
 $ed = $ed=~/^\d+$/? $lang::Ed[$ed] : [split //, $ed];
 # Режим отображения по колонкам:
 # 0: приставка гига/мега/кило
 # 1: B - byte, b - bit
 # 2: если запятая, то 3 знака после запятой, иначе как целое число
 # 3: если установлен, то за секунду
 my $kilo = $cfg::kb;
 if( $ed->[1] eq 'b' )
 {  # отображение в битах
    $traf *= 8;
    $kilo = 1000;
 }
 $traf /= $kilo                 if $ed->[0] eq 'K';
 $traf /= ($kilo*$kilo)         if $ed->[0] eq 'M';
 $traf /= ($kilo*$kilo*$kilo)   if $ed->[0] eq 'G';
 if( $ed->[3] )
 {
    $time<=0 && return '?';
    $traf /= $time;
 }
 return $ed->[2] ? sprintf("%.3f",$traf) : split_n(int $traf);
}

sub Set_traf_ed_line
{
    my($name_ed, $url, $ed_ref) = @_;
    my $i = 0;
    my $ed = int $ses::cookie->{$name_ed};
    $ed = 0 if $ed<0 || $ed> scalar @$ed_ref;
    my $set_traf_ed_line = '';
    foreach my $title ( @$ed_ref )
    {
        $set_traf_ed_line .= $url->a($title, "set_$name_ed"=>$i, (-class=> $i==$ed? 'active': '') );
        $i++;
    }
    return $set_traf_ed_line;
}

sub Save_webses_data
{
 my %p = @_;
 $p{module} ||= '';
 $p{data} = Debug->dump($p{data});
 my $unikey;
 foreach( 1..2 )
 {   # Теоретически, ключ может оказаться не уникальным, поэтому 2 попытки
    $unikey = md5_base64(rand 10**10);
    $unikey =~ s/\+/X/g;
    my $rows = Db->do(
        "INSERT INTO webses_data SET ".
            "created=UNIX_TIMESTAMP(), expire=UNIX_TIMESTAMP()+3*3600, ".
            "role=?, aid=?, unikey=?, module=?, data=? ", 
            $ses::auth->{role}.'', int $ses::auth->{uid}, $unikey, $p{module}, $p{data}
    );
    $rows>0 && return $unikey;
 }
 # если произойдет невозможное: 2 коллизии подряд - пустой ключ будет проигнорирован
 return '';
}

sub Pay_to_DB
{
 my %p = @_;
 $p{uid} ||= $p{mid} || 0;
 $p{cash} = $p{cash} + 0;
 $p{reason} ||= '';
 $p{comment} ||= '';
 $p{time} ||= $ses::t;
 my $creator = $ses::auth->{role};
 my $creator_id = int $ses::auth->{uid};
 return Db->do(
    "INSERT INTO pays SET cash=?, mid=?, category=?, reason=?, comment=?, creator_ip=INET_ATON(?), creator=?, creator_id=?, time=?",
    $p{cash}, $p{uid}, $p{category}, $p{reason}, $p{comment}, $ses::ip, $creator, $creator_id, $p{time},
 );
}

# Персональный платежный код
sub Make_PPC
{
 my($id) = @_;
 my $ppc = 0;
 $ppc += $_ foreach split //,$id;
 $ppc %= 10;
 return $id.$ppc;
}

sub Require_web_mod
{
 my $file = "$cfg::dir_web/$_[0].pl";
 debug("require $file");
 # eval, поскольку ошибка компиляции $file не даст загрузить модули в обработчике die (гугли BEGIN not safe after errors)
 eval{ require $file };
 return "$@";
}


# -----------------------------------------------------------
#
               package Ugrp;
#
# -----------------------------------------------------------

my $Ugrp;
my $Ugrp_list = [];

sub list
{
    $Ugrp && return $Ugrp_list;
    my $db = Db->sql("SELECT * FROM user_grp ORDER BY grp_name");
    Db->ok or return [];
    $Ugrp = {};
    while( my %p = $db->line )
    {
        my $grp = $p{grp_id};
        delete $p{grp_id};
        push @$Ugrp_list, $grp;
        $Ugrp->{$grp} = { map{ $_ => $p{"grp_$_"} } map{ s/grp_//, $_ } keys %p };
    }
    return $Ugrp_list;
}

sub hash
{
    my $pkg = shift;
    $pkg->list;
    return $Ugrp;
}

sub grp
{
    my($pkg, $grp_id) = @_;
    $pkg->list;
    return $Ugrp->{$grp_id} || {};
}

# -----------------------------------------------------------
#
               package Adm;
#
# -----------------------------------------------------------
use Debug;

our $adm = {};
our $list = [];

our $Current_adm  = {};

my $all_load;

sub set_current
{
    $Current_adm = new(@_);
    return $Current_adm;
}

sub new
{
    my($pkg, $p) = @_;
    my $a = {
        id      => $p->{id},
        login   => $p->{login},
        pass    => $p->{pass},
        name    => $p->{name},
        privil  => $p->{privil},
        tunes   => $p->{tunes},
        usr_grps=> $p->{usr_grps},
        url     => $p->{login}, #url->a($p->{login}, a=>'payshow', nodeny=>'admin', admin=>$p->{id}),
    };
    $a->{admin} = $a->{login};
    $a->{admin} .= " ($a->{name})" if $a->{name};
    $a->{priv_hash} = {};
    foreach( split /,/, $p->{privil} )
    {
        $_ or next;
        $a->{priv_hash}{$_} = 1;
        $a->{priv_hash}{$cfg::pr_def{$_}} = 1 if defined $cfg::pr_def{$_};
    }
    bless $a;
    $adm->{$p->{id}} = $a;
    return $a;
}

sub list
{
    my($pkg, $aid) = @_;
    $all_load && return $list;
    my $db = Db->sql("SELECT *,AES_DECRYPT(passwd,?) AS pass FROM admin ORDER BY login", $cfg::Passwd_Key);
    while( my %p = $db->line )
    {
        my $aid = $p{id};
        push @$list, $aid;
        $pkg->new( \%p );
    }
    $all_load = 1;
    return $list;
}

sub get
{
    my($pkg, $aid) = @_;
    $aid = int $aid;
    defined $adm->{$aid} && return $adm->{$aid};
    $pkg->list;
    defined $adm->{$aid} && return $adm->{$aid};
    my $msg = _($lang::adm_is_not_exist, $aid);
    return $pkg->new({ id=>$aid, login=>$msg });
}

sub id {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{id};
}
sub admin {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{admin};
}
sub login {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{login};
}
sub pass {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{pass};
}
sub name {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{name};
}
sub privil {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{privil};
}
sub priv_hash {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{priv_hash};
}
sub tunes {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{tunes};
}
sub usr_grps {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{usr_grps};
}
sub url {
    my $a = ref $_[0]? shift : $Current_adm;
    return $a->{url};
}
sub chk_privil {
    my $a = shift;
    $a = ref $a? $a : $Current_adm;
    return $a->{priv_hash}{$_[0]};
}
sub chk_privil_or_die {
    my($a, $priv, $msg) = @_;
    $a = ref $a? $a : $Current_adm;
    $a->{priv_hash}{$priv} && return;
    debug('warn', "У текущего администратора нет привилегии `$priv`");
    main::Error($msg || $lang::err_no_priv);
}
sub chk_usr_grp {
    my($a, $grp) = @_;
    $a = ref $a? $a : $Current_adm;
    $grp = int $grp;
    return $a->{usr_grps} =~ /,$grp,/;
}
sub usr_grp_list {
    my $a = ref $_[0]? shift : $Current_adm;
    my $grp_list = Ugrp->list;
    return( grep{ $a->{usr_grps} =~ /,$_,/ } @$grp_list );
} 
sub why_no_usr_access {
    my($a, $uid) = @_;
    $a = ref $a? $a : $Current_adm;
    $uid>0 or return "Не задан id клиента";
    my(undef,$grp) = Db->line("SELECT grp FROM users WHERE id=?", $uid);
    Db->ok or return $lang::err_try_again;
    $grp or return "User id=$uid не найден в базе";
    $a->chk_usr_grp($grp) or return "Нет доступа к группе user id=$uid";
    return '';
}
sub exists { defined $_[0]->{name} }

# -----------------------------------------------------------
#
               package ses;
#
# -----------------------------------------------------------
use Debug;
use vars qw( $input );

sub input_exists
{
    return defined $input->{$_[0]};
}

sub input
{
    scalar @_ == 1 && return $input->{$_[0]};
    return( map{ $input->{$_} } @_ );
}

sub input_int
{
    scalar @_ == 1 && return int $input->{$_[0]};
    return( map{ int $input->{$_} } @_ );
}

sub input_all
{
    return %$input;
}

sub cur_module
{
    return $input->{a};
}

# -----------------------------------------------------------
#
               package url;
#
# -----------------------------------------------------------
use Debug;

sub new
{
 my $cls = shift;
 my $it = {};
 bless $it;
 $it->set(%$cls) if ref $cls;
 $it->set(@_);
 return $it;
}

sub set
{
 my $it = shift;
 my %param = @_;
 map{ defined $param{$_}? ($it->{$_} = $param{$_}) : delete $it->{$_} } keys %param;
}

sub url_encode
{
 my $url = shift;
 utf8::is_utf8($url) && utf8::encode($url);
 $url =~s /([^a-zA-z0-9])/sprintf('%%%02X',ord($1))/eg;
 return $url;
}

sub url
{
 my $it = shift;
 $it = $it->new(@_);
 my $url = $it->{-base} || '';
 if( $it->{-trust} || defined $it->{-made} )
 {
    my %param = map{ $_ => $it->{$_} } grep{ /^[^\-]/ } keys %$it;
    my $data = { -input=>\%param };
    $data->{-made} = { msg=>$it->{-made}, created=>$ses::t, error=>$it->{-error} } if defined $it->{-made};
    return $url."?_unikey=".main::Save_webses_data( module=>$it->{a}, data=>$data );
 }

 my $separator = $url =~ /\?/? '&amp;' : '?';
 my $s = $it->{-separator} || '&amp;';
 while( my($key,$val) = each %$it )
 {
    substr($key, 0, 1) eq '-' && next;
    $url .= $separator.url_encode($key).'='.url_encode($val);
    $separator = $s;
 }
 return $url;
}

sub a
{
 my $it = shift;
 my $title = shift;
 $it = $it->new(@_);
 my $url = $it->url;

 if( $it->{-ajax} )
 {
    $it->{-class} .= ' ajax';
    delete $it->{-ajax};
 }
 if( $it->{-active} )
 {
    $it->{'-data-active'} = 1;
    delete $it->{-active};
 }
 my %param = ();
 while( my($key,$val) = each %$it )
 {
    $key =~ s/^\-// or next;
    ($key =~ /^(base|center)$/) && next;
    $param{$key} = $val;
 }

 $url = v::tag('a', href=>[$url], -body=>$title, %param);
 $url = main::Center($url) if $it->{-center};
 return $url;
}

sub post_a
{
 my $it = shift;
 my $title = shift;
 my $form_name = v::get_uniq_id();
 $title = "<a href='javascript:document.$form_name.submit();'>$title</a>";
 return $it->form( @_, -name=>$form_name, $title );
}

sub form
{
 my $it = shift;
 my $data = pop;
 $it = $it->new(@_);
 my $base = $it->{-base} || '?';
 $it->{-method} ||= 'post';
 my $params = '';
 my %hiddens = ();
 $it->{-onsubmit} = v::filtr($it->{-onsubmit},'; return true') if $it->{-onsubmit};
 while( my($key,$val) = each %$it )
 {
    if( $key =~ s/^\-// )
    {
       ($key =~ /^(base)$/) && next;
       $params .= " $key='".v::filtr($val)."'";
       next;
    }
    $hiddens{$key} = $val;
 }
 if( ref $data eq 'ARRAY' )
 {
    my $tbl = tbl->new( -class=> 'td_tall td_wide' );
    foreach my $p( @$data )
    {
        my $r_col;
        my $l_col = $p->{title};
        if( $p->{type} eq 'descr' )
        {
            $r_col = $p->{value};
        }
        if( $p->{type} eq 'text' )
        {
            $r_col = [v::input_t( name=>$p->{name}, value=>$p->{value})];
        }
        if( $p->{type} eq 'text2' )
        {
            $l_col = [v::filtr($p->{title1}).v::input_t( name=>$p->{name1}, value=>$p->{value1})];
            $r_col = [v::filtr($p->{title2}).v::input_t( name=>$p->{name2}, value=>$p->{value2})];
        }
        if( $p->{type} eq 'submit' )
        {
            $r_col = [v::submit($p->{value})];
        }

        if( defined $l_col)
        {
            $tbl->add('', 'll', $l_col, $r_col);
        }else
        {
            $tbl->add('', 'C', $r_col);
        }
    }
    $data = $tbl->show;
 }
 return "<form action='$base'$params>".v::input_h(%hiddens).$data."</form>";
}

sub redirect
{
 my $it = shift;
 if( !$ses::debug )
 {
    my $cookie = main::_set_cookie_str();
    my $url = $it->new(@_)->url( -separator => '&' );
    print "Status: 303\n".$cookie."Location: ".$url."\n\n";
    exit;
 }
 my $url = $it->new(@_)->url;
 main::ToTop 'Redirect to '.$url;
 main::Show( 
    __PACKAGE__->new->a('redirect', -base=>$url,
    -style => 'display:block; text-align:center; width:100%; padding-top:150px; padding-bottom:150px; background-color: #ffffff;')
 );
 main::Exit();
}

# -----------------------------------------------------------
#
               package tbl;
#
# -----------------------------------------------------------

sub new
{
 my $cls = shift;
 my $it = {};
 bless $it;
 $it->set(%$cls) if ref $cls;
 $it->set(@_);
 $it->{-row1} = 'row1' if ! defined $it->{-row1};
 $it->{-row2} = 'row2' if ! defined $it->{-row2};
 return $it;
}

sub set
{
 my $it = shift;
 ref $it or die 'only obj context';
 my %param = @_;
 map{ $it->{$_} = $param{$_} } keys %param;
}

my $tc="td class='h_center'";
my $tr="td class='h_right'";
my $tl="td class='h_left'";

my %td = (
   'c' => "<$tc>",
   'l' => "<$tl>",
   'r' => "<$tr>",
   'C' => "<$tc colspan='2'>",
   'L' => "<$tl colspan='2'>",
   'R' => "<$tr colspan='2'>",
   '2' => "<$tc colspan='2'>",
   '3' => "<$tc colspan='3'>",
   '4' => "<$tc colspan='4'>",
   '5' => "<$tc colspan='5'>",
   '6' => "<$tc colspan='6'>",
   '7' => "<$tc colspan='7'>",
   '8' => "<$tc colspan='8'>",
   '9' => "<$tc colspan='9'>",
   '0' => "<$tc colspan='10'>",
   't' => "<$tc valign='top'>",
   'T' => "<$tc colspan='2' valign='top'>",
   '^' => "<$tl valign='top'>",
   'E' => "<$tl colspan='3'>",
   ' ' => "<td>",
   '0' => "<$tl style='width:1%' valign='top'>",
);

sub _row
{
 my($it,$row_class,$cmd,@cells) = @_;
 ref $it or die "only obj context";
 my $row = $it->{-row1};
 if( $row_class=~s/\*/$row/ )
 {
    ($it->{-row1},$it->{-row2}) = ($it->{-row2},$it->{-row1}); 
 }
 $it->{rows}++;

 my $out = $row_class? "<tr class='$row_class'>" : '<tr>';
 if( ref $cmd eq 'ARRAY' )
 {
    my $head = '';
    foreach my $cell( @$cmd )
    {
        my $cls = v::filtr( shift @$cell );
        my $key = v::filtr( shift @$cell );
        my $val = v::filtr( shift @$cell );
        $out .= "<td class='$cls'>$val</td>";
        $head .= "<td class='$cls'>$key</td>";
    }
    $it->{head} = "<thead><tr>$head</tr></thead>";
 }
  else
 {
    foreach( split //,$cmd )
    {
        my $cell = shift @cells;
        $_ eq 'h' && next;
        $out .= $td{$_};
        $out .= v::filtr($cell);
        $out .= '</td>';
    }
 }
 return $out.'</tr>';
}

sub add
{
 my $it = shift;
 $it->{data} .= $it->_row(@_);
}

sub ins
{
 my $it = shift;
 $it->{data} = $it->_row(@_).$it->{data};
}

sub rows
{
 my $it = shift;
 return $it->{rows};
}

sub show
{
 my $it = shift;
 ref $it or die 'only obj context';
 $it->set(@_);
 my $prop = '';
 $prop .= " class='$it->{-class}'" if $it->{-class};
 $prop .= " style='$it->{-style}'" if $it->{-style};
 $prop .= " id='$it->{-id}'" if $it->{-id};
 return "<table$prop>".$it->{head}.$it->{data}."</table>" ;
}

# -----------------------------------------------------------
#
               package v;
#
# -----------------------------------------------------------
use Debug;

my $autoid_index = 0;

sub get_uniq_id
{
    return 'id'.$autoid_index++.'_'.int(rand 10**10);
}

sub filtr
{
 local $_=shift;
 ref $_ eq 'ARRAY' && return $_->[0];
 s|&|&amp;|g;
 s|<|&lt;|g;
 s|>|&gt;|g;
 s|'|&#39;|g;
 return $_;
}

sub tag
{
 my $tag = shift;
 my %p = @_;
 my $body = exists $p{-body}? filtr($p{-body})."</$tag>" : '';
 delete $p{-body};
 my $params = join ' ', map{ filtr($_)."='".filtr($p{$_})."'" } keys %p;
 return "<$tag $params>$body";
}

sub div
{
 my %p = @_;
 return tag('div', %p );
}

# Формирование элемента <input> типа hidden
# Вход: ( имя => значение, ... )
sub input_h
{
 my %p = @_;
 return( join '', map{ tag('input', type=>'hidden', name=>$_, value=>$p{$_}) } keys %p );
}


# Формирование элемента <input> типа text
sub input_t
{
 my %p = @_;
 $p{nochange} && return filtr($p{value});
 return tag('input', type=>'text', autocomplete=>'off', %p);
}

# имя, значение, колонок, строк
sub input_ta
{
 my($name,$value,$cols,$rows) = @_;
 return "<textarea name='$name' cols='$cols' rows='$rows'>".filtr($value).'</textarea>';
}

# --- Выпадающий список ---
=head
$_ = v::select(
    name     => 'grp',      # имя тега <select>
    size     => 1,          # размер выпадающего списка, необязательный параметр, по умолчанию = 1
    selected => $grp,       # какой пункт списка будет выбран
    nofit    => 'несуществующая группа', # если ни один пункт списка не будет выбран, то будет создан пункт с таким значением
    options  => [ 1,'первая группа', 2,'вторая группа' ]
);

# сортировка выпадающего списка:
$_ = v::select(
    name     => 'grp',
    size     => 1,
    selected => $grp,
    options  => { 2 => '2 й в списке', 1 => '1й в списке' }
);
=cut
sub select
{
 my %p = @_;
 my $o = $p{options};
 my @options = ref $o eq 'ARRAY'? @$o :
               ref $o eq 'HASH'?  map{ $_ => $o->{$_} } sort{ $o->{$a} cmp $o->{$b} } keys %$o :
               ();
 my $options = '';
 my $was_selected;
 while( $#options>0 )
 {
    my $key = shift @options;
    my $val = shift @options;
    my $selected = $p{selected} eq $key && " selected='selected'";
    $key = v::filtr($key);
    $val = v::filtr($val);
    $was_selected = $val if $selected;
    $options .= "<option value='$key'$selected>$val</option>";
 }
 if( defined $p{nofit} && ! defined $was_selected )
 {
    my $key = v::filtr($p{selected});
    my $val = v::filtr($p{nofit});
    $options .= "<option value='$key' selected='selected'>$val</option>";
    $was_selected = $val;
 }

 $p{nochange} && return $was_selected;

 my $size = int $p{size} || 1;
 my $name = v::filtr($p{name});
 my $class= defined $p{class} && " class='".v::filtr($p{class})."'";
 return "<select name='$name' size='$size'$class>$options</select>";
}

=head
v::checkbox(
    name    => 'chk_box',
    value   => '5',
    label   => 'five',
    checked => 1,
);
=cut
sub checkbox
{
 my %p = @_;
 $p{id} ||= get_uniq_id();
 my $tag = tag( 'input',
    type  => 'checkbox',
    name  => $p{name},
    value => $p{value},
    id    => $p{id},
    ($p{checked}? ( checked => 'checked' ) : ()),
 );
 $tag .= tag('label', for => $p{id}, -body => $p{label});
 return $tag;
}

=head
v::checkbox_list(
    name    => 'chk_box',
    list    => [ 1=>'one', 2=>'two' ],
    checked => '1,2',
    buttons => 1, # кнопки выбрать все/убрать все
);
=cut
sub checkbox_list
{
 my %p = @_;
 my @list = ref $p{list} eq 'ARRAY'? @{ $p{list} } :
            ref $p{list} eq 'HASH'?  %{ $p{list} } :
            ();
 my %checked = map{ $_ => 1 } split /,/,$p{checked};
 my $list = input_h( '__multi' => $p{name}, $p{name} => '' );
 my $br = '';
 while( scalar @list )
 {
    my $val = shift @list;
    my $label = shift @list;
    if( $val eq '' )
    {
        $list .= '<p>'.$label.'</p>';
        $br = '';
    }
     else
    {
        $list .= $br . checkbox(name=>$p{name}, value=>$val, checked=>$checked{$val}, label=>$label);
        $br = '<br>';
    }
    
 }
 if( $p{buttons} )
 {
    my $div_id = get_uniq_id();
    $list = _('[p][]',
        _('[] | []',
            url->a($lang::chkbox_list_all,    -base=>'#chkbox_list_all',    -rel=>$div_id),
            url->a($lang::chkbox_list_invert, -base=>'#chkbox_list_invert', -rel=>$div_id),
        ).
        "<div id='$div_id'>$list</div>"
    );
 }
 return $list;
}


sub radio
{
 my %p = @_;
 $p{id} ||= get_uniq_id();
 my $tag = tag( 'input',
    type  => 'radio',
    name  => $p{name},
    value => $p{value},
    id    => $p{id},
    ($p{checked}? ( checked=>'checked' ) : ()),
 );
 $tag .= tag('label', for=>$p{id}, -body=>$p{label});
 return $tag;
}


sub submit
{
 return main::tmpl('submit', button_title=>$_[0], button_padding=>$_[1]);
}

sub bold
{
 return "<b>$_[0]</b>";
}

sub commas
{
 return "&#171;$_[0]&#187;";
}

sub trim
{
 local $_=shift;
 s|^\s+||;
 s|\s+$||;
 return $_;
}

1;
