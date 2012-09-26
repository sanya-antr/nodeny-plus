#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package nod::tmpl;
use strict;
use Debug;

my $mem = {};

sub render
{
 local $_;
 my($tmpl_name, %T) = @_;
 my $code;
 {
    if( exists $mem->{$tmpl_name} )
    {
        $code = $mem->{$tmpl_name};
        last;
    }

    my $tmpl = '';
    if( ref $tmpl_name )
    {
        $tmpl = $$tmpl_name;
    }
     else
    {
        open(F, "<$tmpl_name") or die "cannot load file $tmpl_name";
        $tmpl .= $_ while(<F>);
        close(F);
    }

    # NoDeny тег one_line, указывающий в блоке серию пробелов и переводы строк заменить одним пробелом
    {
        sub to_space
        {
            my($text) = @_;
            $text =~ s| *\n+ *| |g;
            return $text;
        }
        $tmpl =~ s|\{% *one_line *%\}(.+?)\{% *one_line_end *%\}|to_space($1)|eis;
    }

    my $i = 0;

    # В $code формирует $T{index} = 'текст на входе'; и возвращает index
    sub to_hash
    {
        my($code, $text) = @_;
        $i++;
        $text =~ s|\\|\\\\|g;
        $text =~ s|'|\\'|g;
        $$code .= "\$T{$i} = '$text';\n";
        return "{{$i}}";
    }

    # Все, что не является управляющей последовательностью, заменяем на {{переменная}}, в итоге текст
    #    Здравствуйте.{% if show_time %} Сегодня {{time}} !{% endif %}
    # Будет сконвертирован в
    #    {{1}}{% if show_time %}{{2}}{{time}}{{3}}{% endif %}
    # А в $code:
    #   $T{1} = 'Здравствуйте.'; $T{2} = ' Сегодня '; $T{3} = ' !';
    # В итоге $tmpl будет состоять исключительно из управляющих последовательностей
    $tmpl = '}}'.$tmpl.'{{'; # чтобы текст в начале и конце темплейта был захвачен в регексп
    $tmpl =~ s/(\}\}|%\})(.*?)(\{\{|\{%)/$1.to_hash(\$code,$2).$3/egs;
    chop $tmpl;
    chop $tmpl;
    $tmpl =~ s/^..//;

    sub get_var
    {
        my $var = shift;
        $var =~ /^(or|and|not|eq|ne)$/ && return $var;
        $var =~ /^(lang|cfg|ses)::([^\.]+)\.?(.*)$/ &&
            return "\$$1::$2".join('', map{ "->{$_}" } split /\./, $3);
        return '$T'.join('->', map{ "{$_}" } split /\./, $var);
    }

    my @tmpl = split /\{%/,$tmpl;
    my $tab = 0;
    $tmpl[0] = '%}'.$tmpl[0];
    foreach my $block( @tmpl )
    {
        my $tag = _trim( $block =~ s|^(.*?)%\}||? $1 : $block );
        my($com, $p) =  split /\s+/, $tag, 2;
        $com = lc $com;
        $code .= ($tab>0 && "\t" x $tab);
        if( $com eq 'if' )
        {
            # В $p условие
            # Все, что в кавычках вынесем в переменные
            $p =~ s/['"](.*?)['"]/to_hash(\$code,$1)/egs;
            $p =~ s|([A-Za-z_][\w\.]*)|get_var($1)|eg;
            $p =~ s|\{(\{.+?\})\}|\$T$1|g;
            $p =~ s|==|eq|g;
            $code .= "if( $p ) {";
            $tab++;
        }
        if( $com eq 'else' )
        {
            chop $code;
            $code .= "} else {";
        }
        if( $com eq 'endif' )
        {
            chop $code;
            $code .= "}";
            $tab--;
        }
        if( $com eq 'include' )
        {
            $p = _trim($p);
            my($file_name, $param) =  split /\s+/,$p,2;
            if( $file_name !~ s|\{\{ *([^\} ]+) *\}\}|\$T{$1}|g )
            {
                $file_name = "'$file_name'";
            };
            if( $param ne '' )
            {
                $param =~ s|\{\{ *([^\} ]+) *\}\}|\$T{$1}|g;
                $param = "{$param}";
            }else
            {
                $param = '%T';
            }
            $code .= "\$o .= tmpl($file_name,$param);";
        }
        if( $com eq 'for' )
        {
            my($var,$array) = split / +in +/, $p, 2;
            $array = get_var($array);
            $code .= "if( ref $array eq 'ARRAY'){ foreach( \@{$array} ){ \$T{$var} = \$_;";
            $tab++;
        }
        if( $com eq 'endfor' )
        {
            chop $code;
            $code .= "}}";
            $tab--;
        }
        $code .= "\n";

        my $tabs = ($tab>0 && "\t" x $tab);
        
        $block =~ s/{{}}//g;
        $block =~ s/{{ *(.*?) *}}/get_var($1).'.'/eg;
        $code .= "$tabs\$o .= $block'';\n";
    }

    #debug('pre',$code);
    $mem->{$tmpl_name} = $code;
 }

 my $o;
 eval $code;
 my $err = $@;
 if( $err )
 {
    debug('pre',$code);
    die "Ошибка рендеринга $tmpl_name\n$err";
 }
 
 return $o ;
}

sub _trim
{
 local $_=shift;
 s|^\s+||;
 s|\s+$||;
 return $_;
}

1;
