#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2011
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
use strict;

sub go
{
 my($url,$usr) = @_;
 Doc->template('top_block')->{title} .= '. '.'Локальные ресурсы сети';

 my $msg =<<MSG;
    <div class='h_left txtpadding'>
        <p><a href='http://ultravideo.in/'><img src='$cfg::img_dir/local/video_h.gif' style='vertical-align: middle'> Видеоархив</a></p>
        <p><a href='http://ultraserial.in/'><img src='$cfg::img_dir/local/serial_h.gif' style='vertical-align: middle'> Архив сериалов</a></p>
        <p><a href='http://ultrahdtv.in/'><img src='$cfg::img_dir/local/hdtv_h.gif' style='vertical-align: middle'> Фильмы высокой четкости</a></p>
        <p><a href='http://ultraclips.in/'><img src='$cfg::img_dir/local/clips_h.gif' style='vertical-align: middle'> Музыкальные видеоклипы</a></p>
    </div>
MSG

 Show MessageWideBox( $msg );
}

1;
