#!/bin/env perl -w
# https://github.com/cedriczirtacic/nagios-plugins/
# cicatriz.r00t@gmail.com

use strict;
use warnings;

use constant OK => 0;
use constant WARNING => 1;
use constant CRITICAL => 2;
use constant UNKNOWN => 3;
use Data::Dumper;

my %settings = (
	'asterisk'	=> '/usr/sbin/asterisk',
	'asterisk_param'=> "-rx 'sip show peer \%d'",
	'peer'		=> {
		'number'	=> 0,
		'status'	=> undef,
		'port'		=> 0,
		'addr'		=> undef,
		'response_t'	=> undef,
	},
	'output'	=> undef,
	'state'		=> OK,
	'state_msg'	=> undef,
);

sub help($)
{
	printf STDERR <<EOH, shift;
Usage: ./\%s <peer>
EOH
	exit(1);
}

if($#ARGV < 0 || $ARGV[0] eq "-h" ||  $ARGV[0] eq "-h" ||
	$ARGV[0] !~ /^[0-9]+$/ ){
		help($0);
}
$settings{'peer'}{'number'} = shift || help($0);

if( ! -e $settings{'asterisk'} ){
	warn "$settings{asterisk} isn't an executable.";
	exit(2);
}
my $command = sprintf("$settings{asterisk} $settings{asterisk_param}", $settings{'peer'}{'number'});
open(PIPE, "-|", $command) || die "Couldn't open a pipe.";

while( <PIPE> ){
	chomp;
	$settings{'output'} .= $_;
	# if asterisk couldn't find the peer, then UNKNOWN
	if( $_ eq "Peer $settings{'peer'}{'number'} not found." ){
		$settings{'state'} = UNKNOWN;
		$settings{'state_msg'} = "UNKNOWN: $_";
		last;
	}
	# Address (and port) regexp
	if(m/Addr->IP[\s\t]*\:[\s\t]*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|\([^\)]+\)) (?=Port ([0-9]+)$)/g){
		$settings{'peer'}{'addr'} = $1;
		$settings{'peer'}{'port'} = $2 if(defined $2);
	}
	# Status regexp
	if(m/Status[\s\t]*\:[\s\t]*(OK|LAGGED|UNREACHABLE|UNKNOWN)\s*(?:\(([^\)]+)\))*/gi){
		$settings{'peer'}{'status'} = $1;
		$settings{'peer'}{'response_t'} = $2 if(defined $2);
	}
}

my $status = \$settings{'peer'}{'status'} unless !defined $settings{'peer'}{'status'};
# if status wasn't modified yet
if($settings{'state'} != UNKNOWN){
	# we are going to treat 'state' this way:
	#	CRITICAL: UNREACHABLE,UNKNOWN
	#	WARNING: LAGGED
	#	UNKNOWN: Peer doesn't exists

	if( $$status =~ /UNREACHABLE|UNKNOWN/i){
		$settings{'state'} = CRITICAL;
		$settings{'state_msg'} = "CRITICAL";
	}elsif( $$status =~ /LAGGED/i){
		$settings{'state'} = WARNING;
		$settings{'state_msg'} = "WARNING";
	}else{	$settings{'state_msg'} = "OK"; }
	$settings{'state_msg'} .= ": phone status is $$status|";
	while( my($k,$v) = each(%{ $settings{'peer'} }) ){
		next if !defined $v;
		$settings{'state_msg'}.="$k=$v;";
	}
}

# debug %settings values
print Dumper(%settings) if(defined $ENV{DEBUG});

print $settings{'state_msg'},"\n";
exit($settings{'state'});

__END__
