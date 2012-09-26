#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
# Author: Nastenko Valentin, versus.ua@gmail.com
# History
# 18.02.2009 Created 
# 17.09.2009 Add dopdata support
# 18.10.2009 sv: require mod -> DopdataMod
#              month names -> the language file
# ---------------------------------------------
use Data;

sub go
{
 $f="$cfg::dir_web/dogovor.html";
 open(FL,"<$f") or Error($V? $V._($lang::cannot_load_file,$f) : $cfg::statpl_temp_error,$EOUT);
 $out='';
 $out.=$_ while(<FL>);
 close(FL);

 $year_dog=$year_now + 1900;

 %Dog = (
    day			=> $day_now,		# текущий день
    mon			=> $lang::month_names_for_day[$mon_now],	# текущий месяц
    year		=> $year_dog,		# текущий год (от 1970!)
    fio_clienta		=> $U{$Mid}{o_fio},
    login		=> $U{$Mid}{o_name},
    ip			=> $U{$Mid}{ip},
    contract		=> $U{$Mid}{contract},
 );

 $h=nSql->new({
     dbh		=> $dbh,
     sql		=> "SELECT * FROM dopdata WHERE parent_type=0 AND parent_id=$Mid",
     show		=> 'full',
     comment		=> 'Все данные клиента по последним ревизиям',
 });

 while( $h->get_line( {field_alias => \$field_alias, field_value => \$field_value, field_type => \$field_type} ) )
 {
     $field_value = v::filtr(
       Data->value({
          type  => $field_type,
          alias => $field_alias,
          value => $field_value
       })
     );
     $Dog{$field_alias}=$field_value;
     $Dog{_adr_street}=$field_value if $field_alias eq 'p_street:street:name_street';
  }

 $out=~s/{{(\w+)}}/$Dog{$1}/g;
 print "Content-type: text/html\n\n$out";
 exit;
}

1;
