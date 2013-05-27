#!/usr/bin/perl
# https://github.com/cedriczirtacic/nagios-plugins/
# cicatriz.r00t@gmail.com

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use Carp;

my %ERRORS=(
	'OK'		=> 0,
	'WARNING'	=> 1,
	'CRITICAL'	=> 2,
	'UNKNOWN'	=> 3,
);	
my %settings=(
	'critical'	=> undef,
	'warning'	=> undef,
	'username'	=> $ENV{TSM_USER} || undef,
	'password'	=> $ENV{TSM_PASS} || undef,
	'servername'	=> undef,
	'monitor'	=> 'vtl', # VTL by default
	'monitors'	=> {
		'vtl'		=> {
				sql	=>  "SELECT status,last_use,COUNT(*) AS amount FROM libvolumes WHERE library_name = 'QDXI6700' GROUP BY status,last_use ORDER BY status",
				check	=> "Scratch",
		},
		'tape'		=> {
				sql	=> "SELECT status,last_use,COUNT(*) AS amount FROM libvolumes WHERE library_name = 'SACALARI80' GROUP BY status,last_use ORDER BY status",
				check	=> "Scratch",
		},
	},
	'dsmadmc'	=> '/usr/bin/dsmadmc',
	'dsmadmc_opts'	=> "-NOConfirm",
);

sub usage()
{
	print <<USAGE;
Usage:	$0 [-d|--options dsmadmc_options][-p|--password] [-u|--username] [-s|--servername]
	   [-m|--monitor] -w warning -c critical
USAGE
	exit $ERRORS{UNKNOWN};
}

sub dsmadmc_monitor($$)
{
	my($mon,$_s)=@_;
	return $ERRORS{UKNNOWN} if(!defined $mon);
	my $_command=sprintf("%s %s -commadelimited -dataonly=yes -id=%s -pa=%s -servername=%s \"%s\"",
		$$_s{'dsmadmc'}, $$_s{'dsmadmc_opts'}, $$_s{'username'}, $$_s{'password'},	
		$$_s{'servername'}, $$_s{'monitors'}{$mon}{sql});
	my $_data;
	
	# Using chdir() for a quick and dirty hack to avoid dmserror.log from
	# fucking with permissions
	if(chdir('/tmp') && open(DSMADMC, "$_command |")){
		while(<DSMADMC>){
			$_data=$1 if(/^($$_s{'monitors'}{$mon}{check} .+)$/xgi);
		}
		close(DSMADMC);
	}

	if(!defined $_data){
		print "CRITICAL: No data '$$_s{'monitors'}{$mon}{check}' found in output.\n";
		return $ERRORS{CRITICAL};
	}
	if(my($_last_use,$_count)= $_data =~ /^Scratch,(.*),([0-9]+)$/gi){
		if(!defined $_count){
			print "CRITICAL: Invalid or malformed output.\n";
			return $ERRORS{CRITICAL};
		}

		if($_count <= $$_s{critical}){
			print "CRITICAL: $$_s{'monitors'}{$mon}{check} has count $_count < $$_s{critical}\n";
			return $ERRORS{CRITICAL};
		}elsif($_count <= $$_s{warning}){
			print "WARNING: $$_s{'monitors'}{$mon}{check} has count $_count < $$_s{warning}\n";
			return $ERRORS{WARNING};
		}else{
			print "OK: $$_s{'monitors'}{$mon}{check} has count $_count\n";
			return $ERRORS{OK};
		}
	}
}

sub main()
{
	my %opts=(
		'h|help'	=> \&usage,
		'u|username=s'	=> \$settings{username},
		'p|password=s'	=> \$settings{password},
		's|servername=s'=> \$settings{servername},
		'w|warning=i'	=> \$settings{warning},
		'c|critical=i'	=> \$settings{critical},
		'd|options=s'	=> \$settings{dsmadmc_opts},
		'm|monitor=s'	=> \$settings{monitor},
	);
	&usage if($#ARGV < 1);
	
	# Lets complain about everything!
	Carp::croak 'Error while getting params' if(!GetOptions(%opts));
	if(!-f $settings{'dsmadmc'} || !-e $settings{'dsmadmc'}){
		Carp::croak "Problems with the binary: $settings{dsmadmc}";
	}
	Carp::carp "You must define a username and password!" and &usage if(!defined($settings{password}) || !defined($settings{username}));
	Carp::carp "You must define a servername" and &usage if(!defined($settings{servername}));

	if(!defined $settings{monitor} ||
		!defined $settings{monitors}{$settings{monitor}}){
		print STDERR "Undefined monitor. List of available monitoring schemas: \n";
		print "* $_\n" for keys %{$settings{monitors}};
		
		return $ERRORS{UNKNOWN};
	}

	my $mon_output=dsmadmc_monitor($settings{monitor}, \%settings);
	return($mon_output);
}

exit main();
