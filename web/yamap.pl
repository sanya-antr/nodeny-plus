#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
 my($url) = @_;
 Adm->chk_privil_or_die('topology');

 $cfg::yamap_key ne '' or debug('error', 'Нет ключа для yandex api ($cfg::yamap_key)');
 $cfg::yamap_url ||= 'https://api-maps.yandex.ru/1.1/index.xml?key=';

 my %map_param = (
    map_url   => $cfg::yamap_url.$cfg::yamap_key,
    map_scale => $cfg::yamap_scale || 17,
 );

 if( $cfg::yamap_center =~ /^(\d+\.\d+),(\d+\.\d+)$/ )
 {
    $map_param{map_center_x} = $1;
    $map_param{map_center_y} = $2;
 }
  else
 {
    debug('error', 'Не указан центр карты ($cfg::yamap_center)');
    # Берем город автора
    $map_param{map_center_x} = 35.066425;
    $map_param{map_center_y} = 48.466633;
 }

 # --- Графический выбор времени ---
 {
    # Вверху линия слайдера времени
    ToTop _('[div id=time_slider]','');

    my $tbl = tbl->new( -class=>'td_ok', -id=>'time_form' );
    $tbl->add('', 'll', 'Дата',    [v::input_t(name=>'date', value=>the_date($ses::t), size=>7, class=>'dateinput')]);
    $tbl->add('', 'll', 'Время',   [v::input_t(name=>'hh_mm', value=>the_hour($ses::t), size=>7)]);
    ToRight WideBox( title=>'Авторизации', msg=>$tbl->show );
 }

 ToRight WideBox( title=>'Все клиенты', msg=>url->a('На карту', -ajax=>1, a=>'ajYamapGet', -class=>'mark_col_btn'));

 my $db = Db->sql("SELECT * FROM webses_data WHERE aid=? AND module='yamap' ORDER BY created DESC LIMIT 6", Adm->id);
 while( my %p = $db->line )
 {
    my $VAR1;
    my $data = eval $p{data};
    if( $@ )
    {
        debug('warn', "Ошибка парсинга данных по ключу `$p{unikey}`: $@");
        next;
    }
    ref $data eq 'HASH' or next;
    $data->{from} eq 'users' or next;       # данные от модуля ...
    ref $data->{ids} eq 'ARRAY' or last;    # список id по фильтру
    ref $data->{info} eq 'ARRAY' or last;   # фильтр в html-заэскейпеном виде
    my $filtr = _('[p]', join '<br>', @{$data->{info}});
    my $time = the_hh_mm($ses::t-$p{created}).' назад';
    ToRight Box( wide=>1, title=>$time, msg=>
        $filtr.
        join(' | ',
            url->a('На карту', -ajax=>1, a=>'ajYamapGet', unikey=>$p{unikey}, -class=>'mark_col_btn' ),
            url->a('Обновить', _unikey=>$data->{return_to}),
            url->a('Изменить', _unikey=>$data->{return_to}, mod=>''),
            url->a('x', a=>'operations', act=>'del_ses_data', unikey=>$p{unikey}, return_to=>'yamap'),
        )
    );
 } 

 # Если есть привилегия изменения допданных - точки можно перемещать по карте
 $map_param{Marks_draggable} = Adm->chk_privil(80)? 'true' : 'false';

 Show tmpl('yamap', %map_param);
 Doc->template('base')->{document_ready} .= " YaMaps();";

}
1;
