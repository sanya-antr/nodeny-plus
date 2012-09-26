#!/usr/bin/perl
# ------------------- NoDeny ------------------
# Copyright (с) Volik Stanislav, 2008..2012
# Read license http://nodeny.com.ua/license.txt
# ---------------------------------------------
package kernel;
use strict;
use FindBin;
use lib $FindBin::Bin;
use new;

my $run_only_mod;
my $list_all_mod;

my $M = kernel->new(
    file_cfg => 'sat.cfg',
    file_log => 'nokernel.log',
);

$M->{cmd_line_options} = {
    'm=s'   => \$run_only_mod,
    'L'     => \$list_all_mod,
};

$M->{help_msg} = 
    "    -m=mod  : run only module `mod`\n".
    "    -L      : list all modules\n";

$M->Start;

foreach( 0..59 )
{
    $M->Is_terminated && exit;
    my %p = Db->line("SELECT * FROM config ORDER BY time DESC LIMIT 1");
    %p or next; # паузу можно не делать т.к. она будет между попытками соединения в модуле Db
    $cfg::config = $p{data};
    last;
}
$cfg::config or die "Error getting config from DB";

eval "
    no strict;
    $cfg::config;
    use strict;
";

$@ && die "Error config: $@";

eval "use kernel::cfg";
$@ && die $@;

if( $list_all_mod )
{
    tolog(sprintf "\n%-24s %-10s", 'MODULE', 'RUN?');
    foreach my $plg( keys %$cfg::plugins )
    {
        my $param = $cfg::plugins->{$plg};
        tolog(sprintf '%-24s %-10s', $plg, $param->{run});
    }
    exit;
}

$run_only_mod && !$cfg::plugins->{$run_only_mod} && die "there is no `$run_only_mod` in kernel::cfg.pm";

foreach my $plg( keys %$cfg::plugins )
{
    my $param = $cfg::plugins->{$plg};
    if( $run_only_mod )
    {
        $run_only_mod ne $plg && next;
    }
     else
    {
        $param->{run} or next;
    }
    $plg = "kernel::$plg";
    tolog("loading $plg.pm");
    eval "use $plg";
    $@ && die $@;

    $plg->start( $run_only_mod, $param );
}

nod::tasks->run;

exit;

1;
