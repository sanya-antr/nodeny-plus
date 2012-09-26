#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package Data;
use strict;
use Debug;
use Db;

=head
 Объект Data = {
    id      => 15,              # id поля по таблице datasetup, для других таблиц не существует
    order   => 1,               # Алфавитная сортировка поля либо приоритет в поиске
    type    => 8,               # Тип поля
    name    => '_adr_street',   # Реальное имя поля
    title   => 'Улица',         # Имя поля для клиента
    flags   => 'aq',
    flag    => { a=>1, q=>1 },  # то же, что и flags, только хешем
    param   => 'street'         # Для `выпадающего списка` param указывает на имя словаря, иначе regexp
    value   => 14,              # Значение поля
    search  => 2,               # Разрешен поиск: 2 - глобальный, 1 - обычный, 0 - нет
    s_mode  => 0,               # Режим поиска по умолчанию (0 начинается с, 1 фрагмент, 2 =, 3 не =, 4 >, 5 <)
    s_str   => '',              # Строка поиска по умолчанию
}
=cut

my %type_proc = (
    0  => 'num_int',
    1  => 'num_uint',
    2  => 'num_float',
    3  => 'num_ufloat',
    4  => 'str_one',
    5  => 'str_many',
    6  => 'yes_no',
    8  => 'select',
    9  => 'pass',
    10 => 'traffic',
    11 => 'time',
    13 => 'money',
    20 => 'hash',
);

my $mem = {};

# --- Загрузим словарь ---
# $mem->{dictionary}{тип_словаря} = [ key1 => value1, key2 => value2 ]

my $dictionary = {};
my $db = Db->sql("SELECT type,k,v FROM dictionary ORDER BY v");
while( my %p = $db->line )
{
    my $type = $p{type};
    $dictionary->{$type} ||= [];
    push @{ $dictionary->{$type} }, $p{k}, $p{v};
}

$mem->{dictionary} = $dictionary;

my $services = [];
my $db = Db->sql("SELECT service_id, title FROM services ORDER BY module, title");
while( my %p = $db->line )
{
    push @$services, $p{service_id} => $p{title};
}

our $All_fields = {};

my $Ips_fields = [
    {
        name    => 'ip',
        title   => 'ip',
        type    => 4,
        search  => 2,
        s_mode  => 0,
        s_str   => '10.',
    },
    {
        name    => 'auth',
        title   => 'Авторизация',
        type    => 6,
        search  => 1,
        s_mode  => 2,
        s_str   => 1,
    },
    {
        name    => 'tm_auth',
        title   => 'Длит. авторизации, сек',
        type    => 1,
        search  => 1,
        s_mode  => 5,
        s_str   => 600,
    },
    {
        name    => 'properties',
        title   => 'Параметры авторизации',
        type    => 4,
        search  => 1,
        s_mode  => 0,
        s_str   => 'mod=radius',
    }
];

my $Srv_fields = [
    {
        name    => 'service_id',
        title   => 'Услуга',
        type    => 20,
        search  => 1,
        s_mode  => 2,
        hash    => $services,
    }
];

my $Fullusers_fields = [
    {
        name    => 'fio',
        title   => $lang::fullusers_fields_name->{fio} || 'ФИО',
        type    => 4,
        search  => 2,
    },
    {
        name    => 'name',
        title   => $lang::fullusers_fields_name->{name} || 'Логин',
        type    => 4,
        search  => 2,
    },
    {
        name    => 'contract',
        title   => $lang::fullusers_fields_name->{contract} || 'Договор',
        type    => 4,
        search  => 2,
    },
    {
        name    => 'comment',
        title   => $lang::fullusers_fields_name->{comment} || 'Комментарий',
        type    => 5,
        search  => 1,
    },
    {
        name    => 'id',
        title   => 'Id',
        type    => 1,
        search  => 2,
    },
    {
        name    => 'balance',
        title   => $lang::fullusers_fields_name->{balance} || 'Баланс',
        type    => 13,
        search  => 1,
        s_mode  => 5,
        s_str   => '0',
    },
    {
        name    => 'traf',
        title   => $lang::fullusers_fields_name->{traf} || 'Трафик, Мб',
        type    => 1,
        search  => 1,
        s_mode  => 4,
        s_str   => '0',
    },
    {
        name    => 'traf_out',
        title   => $lang::fullusers_fields_name->{traf_out} || 'Исх. трафик, Мб',
        type    => 1,
        search  => 1,
        s_mode  => 4,
        s_str   => '0',
    },
    {
        name    => 'traf_in',
        title   => $lang::fullusers_fields_name->{traf_in} || 'Вх. трафик, Мб',
        type    => 1,
        search  => 1,
        s_mode  => 4,
        s_str   => '0',
    },
    {
        name    => 'traf1',
        title   => 'Трафик 1 направления, Мб',
        type    => 1,
        search  => 1,
        s_mode  => 4,
        s_str   => '0',
    },
    {
        name    => 'grp',
        title   => 'Группа',
        type    => 1,
        search  => 0,
    },
    {
        name    => 'state',
        title   => 'Доступ',
        type    => 20,
        search  => 1,
        hash    => { 'on' => $lang::on, 'off' => $lang::off },
        s_mode  => 2,
        s_str   => 'off',
    },
    {
        name    => 'lstate',
        title   => 'Без авторизации',
        type    => 6,
        search  => 1,
        s_mode  => 2,
        s_str   => 1,
    },
    {
        name    => 'cstate',
        title   => 'Состояние',
        type    => 20,
        search  => 1,
        hash    => \%lang::cstates,
        s_mode  => 4,
        s_str   => 2,
    },
    {
        name    => 'contract_date',
        title   => 'Дата договора',
        search  => 0,
    },
    {
        name    => 'passwd',
        title   => 'Пароль',
        type    => 9,
        search  => 0,
    },
    {
        name    => 'limit_balance',
        title   => 'Граница отключения',
        type    => 13,
        search  => 1,
        s_mode  => 5,
        s_str   => 0,
    },
    {
        name    => 'block_if_limit',
        title   => 'Блокировать по балансу',
        type    => 6,
        search  => 1,
        s_mode  => 2,
        s_str   => 0,
    },
    
];

my $order = 0;

foreach my $field( @$Fullusers_fields )
{
    bless $field;
    $field->{tbl} = 'u';
    $field->{order} = $order++;
    $All_fields->{'u'.$field->{name}} = $field;
}
foreach my $field( @$Ips_fields )
{
    bless $field;
    $field->{tbl} = 'i';
    $field->{order} = $order++;
    $All_fields->{'i'.$field->{name}} = $field;
}
foreach my $field( @$Srv_fields )
{
    bless $field;
    $field->{tbl} = 's';
    $field->{order} = $order++;
    $All_fields->{'s'.$field->{name}} = $field;
}

my $Data_fields = {};
my $db = Db->sql("SELECT * FROM datasetup ORDER BY template, title");
while( my %p = $db->line )
{
    my $alias = $p{name};
    # Поиск по полю `пароль` запрещен
    $p{search} = $p{type} != 9? 2 : 0;
    # Поиск по умолчанию `начинается с` для строковых полей, ниначе `=`
    $p{s_mode} = $p{type} =~ /^(4|5)$/? 0 : 2;
    $p{order}  = $order++;
    $p{title}  = main::Del_Sort_Prefix($p{title});
    $p{flag} = { map{ $_ => 1 } split //, $p{flags} };
    $p{tbl} = 'd';
    $Data_fields->{$alias} = \%p;
    bless $Data_fields->{$alias};
    $All_fields->{"d$alias"} = $Data_fields->{$alias};
}



#-------------------------------------------------------------------------------

sub get_fields
{
 my($it, $uid) = @_;

 my %p = $uid>0? Db->line("SELECT * FROM data0 WHERE uid=? LIMIT 1", $uid) : (uid => 0);
 my $fields = {};
 foreach my $alias( sort{ $Data_fields->{$a}{order} <=> $Data_fields->{$b}{order} } keys %$Data_fields )
 {
        # реальное имя поля
        my $name = $Data_fields->{$alias}{name};
        my $field = {
            name    => $name,
            value   => $p{$name},
            uid     => $p{uid},
            %{$Data_fields->{$alias}}
        };
        bless $field;
        $fields->{$alias} = $field;
 }
 return $fields;
}

#-------------------------------------------------------------------------------

sub save
{
 my($it, $fields) = @_;
 my $sql = 'UPDATE data0 SET ';
 my @sql_param = ();
 my $uid;
 my $separator = '';
 foreach my $alias( keys %$fields )
 {
    my $field = $fields->{$alias};
    my $value = $field->{new_value};
    defined $value or next;
    my($err_msg, $save_value) = $field->check();
    if( $err_msg )
    {
        debug('warn', 'pre', {
            title   => $field->{title},
            name    => $field->{name},
            value   => $value,
            err_msg => $err_msg,
        });
        return $err_msg;
    }
    $uid = $field->{uid};
    $sql .= $separator."$field->{name} = ?";
    push @sql_param, $save_value;
    $separator = ',';
 }

 my $rows = Db->do("$sql WHERE uid=?", @sql_param, $uid);
 return $rows<1? 'Sql error' : '';
}


#-------------------------------------------------------------------------------

sub check
{
 my($field, %p) = @_;
 my $it = {};
 bless $it;
 map{ $it->{$_} = $field->{$_} } keys %$field;
 map{ $it->{$_} = $p{$_} } keys %p;

 my $flag  = $it->{flag};
 my $type  = $it->{type};
 my $value = $it->{value};

 if( exists $it->{new_value} )
 {
    $value = $it->{new_value};
    $value =~ s|^\s+||              if $flag->{b}; # убирать пробелы в начале
    $value =~ s|\s+$||              if $flag->{c}; # убирать пробелы в конце
    $value = main::lc_rus($value)   if $flag->{d}; # преобразовать к нижнему регистру
    $value = main::translit($value) if $flag->{e}; # транслировать в латинские символы
    $value =~ s|\s+||g              if $flag->{f}; # убирать все пробелы
    $it->{new_value} = $value;
 }

 $value eq '' && return('', '');

 $flag->{b} && $value =~ m|^\s+| && return 'Начальные пробелы недопустимы';
 $flag->{c} && $value =~ m|\s+$| && return 'Завершающие пробелы недопустимы';
 $flag->{f} && $value =~ m|\s|   && return 'Пробелы недопустимы';
 if( $type !=8 && $it->{param} ne '' && $value !~ /$it->{param}/ )
 {
    debug('warn', 'pre', 'Не соответствует шаблону:', { name => $it->{name}, value => $value, regexp => $it->{param} } );
    return 'Не соответсвует шаблону';
 }

 my $method = 'check_'.$type_proc{$type};
 if( ! $it->can($method) )
 {
    debug('warn', "no sub `$method`");
    return '';
 }
 my($err_msg,$save_value) = $it->$method($value);
 $err_msg && return $err_msg;

 if( $flag->{h} && Db->line("SELECT 1 FROM data0 WHERE $it->{name}=? AND uid<>? LIMIT 1", $save_value, $it->{uid}) )
 {
    return 'Значение должно быть уникальным';
 }
 return('',$save_value);
}


sub check_num_int
{
 my($it, $value) = @_;
 $value =~ s| ||g;
 $value !~ /^\-?\d+$/ && return 'Необходимо ввести положительное или отрицательное число';
 return('', $value);
}

sub check_num_uint
{
 my($it, $value) = @_;
 $value =~ s| ||g;
 $value !~ /^\d*$/ && return 'Необходимо ввести целое положительное число';
 return('', $value);
}

sub check_num_float
{
 my($it, $value) = @_;
 $value =~ s| ||g;
 $value !~ /^\-?\d+\.?\d*$/ && return 'Необходимо ввести положительное или отрицательное число';
 return('', $value);
}

sub check_num_ufloat
{
 my($it, $value) = @_;
 $value =~ s| ||g;
 $value !~ /^\d+\.?\d*$/ && return 'Необходимо ввести положительное число';
 return('', $value);
}

sub check_str_one
{
 my($it, $value) = @_;
 return('', $value);
}

sub check_str_many
{
 my($it, $value) = @_;
 return('', $value);
}

sub check_yes_no
{
 my($it, $value) = @_;
 $value !~ /^[01]$/ && return 'Необходимо выбрать одно из значений';
 return('', $value);
}

sub check_select
{
 my($it, $value) = @_;
 my $dict_type = $it->{param};
 my %dictionary = @{$mem->{dictionary}{$dict_type}};
 exists $dictionary{$value} or return 'Необходимо выбрать одно из значений';
 return('', $value);
}

sub check_pass
{
 my($it, $value) = @_;
 return('', $value);
}

sub check_traffic
{
 my($it, $value) = @_;
 return $it->check_num_int($value);
}

sub check_time
{
 my($it, $value) = @_;
 if( exists $it->{new_value} )
 {
    my $value = v::trim($it->{new_value});
    $value =~ s/ *: */:/g;
    # [дд] чч:мм:cc
    $value =~ m|(\d+):(\d+):(\d+)$| or return 'Необходимо ввести время в ввиде `чч:мм:сс` либо `дд чч:мм:сс`';
    ( $1>59 || $2>59 || $3>59 ) && return 'Проверьте, чтобы секунды и минуты были < 60, а часы <24';
    my $time = $1*3600 + $2*60 + $3;
    $time += $1*24*3600 if $value =~ m|(\d+)|;
    return('', $time);
 }
 $value !~ /^\d+$/ && return 'Неверно задано';
 return('', $value);
}

sub check_money
{
 my($it, $value) = @_;
 return $it->check_num_float($value);
}

sub check_hash
{
 my($it, $value) = @_;
 return('', $value);
}

#-------------------------------------------------------------------------------


sub show
{
 my($it, %p) = @_;
 my $cmd = $p{cmd} =~ /^(form|search)$/? $p{cmd} : 'show';
 return $it->_proc($cmd, %p);
}

sub form
{
 my $it = shift;
 return $it->_proc('form', @_);
}

sub search
{
 my $it = shift;
 return $it->_proc('search', @_);
}

#-------------------------------------------------------------------------------

sub _proc
{
 my($field, $cmd, %p) = @_;
 my $it = {};
 bless $it;
 map{ $it->{$_} = $field->{$_} } keys %$field;
 map{ $it->{$_} = $p{$_} } keys %p;

 my $method = $cmd eq 'search'? 'form' : $cmd;
 $method .= '_'.$type_proc{$it->{type}};

 if( $it->can($method) )
 {
    $cmd eq 'search'  && return $it->$method( 1, $it->{iname} );
    $cmd eq 'form'    && return $it->$method( 0, $it->{iname} );
    $it->{value} eq '' && return '';
    return $it->$method( $it->{value} );
 }

 debug('warn', "no sub `$method`");
 return '';
}


#-------------------------------------------------------------------------------


sub show_num_int
{
 my($it, $value) = @_;
 return v::filtr($value);
}

sub show_num_uint
{
 my($it, $value) = @_;
 return v::filtr($value);
}

sub show_num_float
{
 my($it, $value) = @_;
 return v::filtr($value);
}

sub show_num_ufloat
{
 my($it, $value) = @_;
 return v::filtr($value);
}

sub show_str_one
{
 my($it, $value) = @_;
 return v::filtr($value);
}

sub show_str_many
{
 my($it, $value) = @_;
 my $value = v::filtr($value);
 $value =~ s/\n/<br>/g;
 return $value;
}

sub show_yes_no
{
 my($it, $value) = @_;
 return v::filtr( $value eq ''? '': $value? $lang::yes : $lang::no );
}

sub show_select
{
 my($it, $value) = @_;
 my $dict_type = $it->{param};
 my %dictionary = @{$mem->{dictionary}{$dict_type}};
 return v::filtr( $dictionary{$value} );
}

sub show_pass
{
 my($it, $value) = @_;
 return '*****';
}

sub show_traffic
{
 my($it, $value) = @_;
 return main::Print_traf($value, $ses::tunes{ed});
}

sub show_time
{
 my($it, $value) = @_;
 return _the_hh_mm_ss($value);
}

sub show_money
{
 my($it, $value) = @_;
 return v::filtr($value);
}

sub show_hash
{
 my($it, $value) = @_;
 my %p = ref $it->{hash} eq 'HASH'? %{$it->{hash}} : 
         ref $it->{hash} eq 'ARRAY'? @{$it->{hash}} : ();
 return v::filtr( $p{$value} );
}

#-------------------------------------------------------------------------------


sub form_num_int
{
 my $it = shift @_;
 return $it->form_str_one(@_);
}

sub form_num_uint
{
 my $it = shift @_;
 return $it->form_str_one(@_);
}

sub form_num_float
{
 my $it = shift @_;
 return $it->form_str_one(@_);
}

sub form_num_ufloat
{
 my $it = shift @_;
 return $it->form_str_one(@_);
}

sub form_str_one
{
 my($it, $is_search, $iname) = @_;
 my $value = exists $it->{new_value}? $it->{new_value} : $it->{value};
 return v::input_t( name=>$iname, value=>$value );
}

sub form_str_many
{
 my($it, $is_search, $iname) = @_;
 $is_search && return $it->form_str_one($is_search, $iname);
 my $value = exists $it->{new_value}? $it->{new_value} : $it->{value};
 return v::input_ta($iname, $value, 20, 5);
}

sub form_pass
{
 my($it, $is_search, $iname) = @_;
 return v::input_t( name=>$iname, value=>'' );
}

sub form_yes_no
{
 my($it, $is_search, $iname) = @_;
 my $m = [ '', '', 0, $lang::no, 1, $lang::yes ];
 my $value = exists $it->{new_value}? $it->{new_value} : $it->{value};
 my $select = v::select(
    name     => $iname,
    size     => 1,
    selected => $value,
    options  => $m,
 );
 return $select;
}

sub form_select
{
 my($it, $is_search, $iname) = @_;
 my $value = exists $it->{new_value}? $it->{new_value} : $it->{value};
 my $dict_type = $it->{param};
 exists $mem->{dictionary}{$dict_type} or return '';
 my $select = v::select(
    name     => $iname,
    size     => 1,
    selected => $value,
    options  => [ '' ,'', @{$mem->{dictionary}{$dict_type}} ],
 );
 return $select;
}

sub form_traffic
{
 my($it, $is_search, $iname) = @_;
 my $value = exists $it->{new_value}? $it->{new_value} : $it->{value} eq ''? '' : main::split_n($it->{value});
 return v::input_t( name=>$iname, value=>$value );
}

sub form_time
{
 my($it, $is_search, $iname) = @_;
 my $value = exists $it->{new_value}? $it->{new_value} : $it->{value} eq ''? '' : _the_hh_mm_ss($it->{value});
 return v::input_t( name=>$iname, value=>$value );
}

sub form_money
{
 my $it = shift @_;
 return $it->form_str_one(@_);
}

sub form_hash
{
 my($it, $is_search, $iname) = @_;
 my $value = exists $it->{new_value}? $it->{new_value} : $it->{value};
 my $select = v::select(
    name     => $iname,
    size     => 1,
    selected => $value,
    options  => $it->{hash},
 );
 return $select;
}

sub _the_hh_mm_ss
{
 my($val) = @_;
 my $res = '';
 foreach( 24*3600, 3600, 60, 1 )
 {
    $res = sprintf "%s:%02d", $res, int($val/$_);
    $val = $val % $_;
 }
 $res =~ s|:(\d\d):|$1 |;
 $res =~ s|00 || && return $res;
 $res =~ s|(\d+) |$1 дн. |;
 return $res;
}


1;


__END__



 
1;
