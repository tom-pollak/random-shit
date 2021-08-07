#!perl

use strict;

############################################################################
## TITLE: race_place_probs.pl
## AUTHOR: Ganchrow (ganchrow@yahoo.com)
## SYNOPSIS: Reads from STDIN a set of newline-separated absolute win
## probabilities for any number of race particpants. This script will first
## normalizes the input probabilities, ensuring they sum to unity, and then
## will send to STDOUT the probabilities of each participant
## finishing in each of 1st through +RELEVANT_PLACES place.
## The script iterates recursively through the structure of win
## probabilities, summing up the probabilities of every feasible outcome
## (up to RELEVANT_PLACES places each).
############################################################################
## Copyright © 2010 Scott Eisenberg
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
## 
## You may find a copy of the GNU General Public License
## at http://www.gnu.org/licenses/gpl.html.
############################################################################

use Time::HiRes;

## Change the following line to determine for how many finishing positions probabilities are output.
use constant RELEVANT_PLACES => 8;	# number of places for which we want to calculate win probabilities

## Change the following line to control the output precision inclusive of the percentage.
## A value of 4, for example, would display output in the form #.##%
use constant OUTPUT_PRECISION => 8;	# number of decimal places for output after percentage

## DO NOT change the following line
use constant REGEXP_FLOAT => qr/^(?:[+-]?)(?=\d|\.\d)\d*(?:\.\d*)?(?:[Ee](?:[+-]?\d+))?$/;

my $start_time = Time::HiRes::time();


MAIN: {
	my $place_probs_r = [ [] ]; 	# $place_probs_r->[$x]->[$i] = probability of driver $i+1 finishing in place $x+1

	&read_and_normalize_data($place_probs_r->[0]);
	&recurse($place_probs_r);
    use Data::Dumper;
    my $str = Dumper($place_probs_r);
    print($str);
	&display_probs($place_probs_r);
}


sub recurse {
	my $ptr = shift;			# pointer to probability structure
    # print "@{$ptr}\n\n";


	my $n = (				# total number of drivers
		shift ||
		scalar( @{$ptr->[0]} )
	);					
	my $cur_neg_prob = (shift || 1);	# current inverse probability of outcome
	my $cur_adj_factor = (shift || 1);	# current adjustment factor for outcome
	my $included_r = (shift || {});		# HASH ref of driver numbers already included in outcome
	(my $recursion_level = (shift || 0))++;	# winning position # currently being evaluated

	for(my $i = 0; $i < $n; $i++) {
		next if defined($included_r->{$i});

		my $prob = $ptr->[0]->[$i];
		$ptr->[$recursion_level-1]->[$i] += $prob * $cur_adj_factor if $recursion_level > 1;
		if ($recursion_level < RELEVANT_PLACES) {
			my $neg_prob = $cur_neg_prob - $prob;
			my $adj_factor = $cur_adj_factor * $prob / $neg_prob;
			$included_r->{$i} = 1;
			&recurse($ptr, $n, $neg_prob, $adj_factor, $included_r, $recursion_level);
			undef($included_r->{$i});
		}
	}
}

sub read_and_normalize_data {
	my $win_probs_r = shift;

	my $total_prob = 0;	# normalization factor
	my $n = 0;		# number of drivers
	while(<>) {
		# read in data file of win probabilities

		s/[^0-9.%Ee+-]+//gs; # remove white space and non-numeric characters

		if (! m/\d/ ) {
			warn "Skipping non-numeric line# $.\n";
			next;
		}

		$_ /= 100 if(s/%$//); 	# adjust if probs quoted as percentages

		if ($_ =~ REGEXP_FLOAT and $_ > 0){
			# add win probability to array refenced by
			# $place_probs_r->[0] (1st place finish)
			# increase $total_prob so we can normalize later

			$win_probs_r->[$n++] = 0+$_;
			$total_prob += $_;
		} else {
			warn "Skipping line # $. with prob=$_\n";
			next;
		}
	}

	if ($n < RELEVANT_PLACES) {
		die "Invalid input data: Only $n drivers and " . RELEVANT_PLACES . " places.\n";
	} elsif ($total_prob <= 0) {
		die "Invalid input data: Total probability = $total_prob\n";
	}
	&normalize_probs($win_probs_r, $total_prob);
}

sub normalize_probs {
	my $win_probs_r = shift;
	my $total_prob = shift;
	if ($total_prob != 1 ) {
		# normalize win probabilities to ensure they sum to unity
		warn "Normalizing win probabilities by a factor of $total_prob\n";
		@{$win_probs_r} = map { $_ /= $total_prob } @{$win_probs_r};
	}
}

sub display_probs {
	my $ptr = shift;
	my $prec = int(+OUTPUT_PRECISION - 2);
	$prec = 0 if $prec < 0;
	my $n = scalar(@{$ptr->[0]});
	my $buffer = '';
	for (my $i = 1; $i <= RELEVANT_PLACES; $i++) {
		$buffer .= "\t$i";
	}
	print "$buffer\n";
	$buffer = '';
	for (my $i = 0; $i < $n; $i++) {
		$buffer = ($i+1) . '';
		for (my $j = 0; $j < RELEVANT_PLACES; $j++) {
			$buffer .= sprintf("\t%0.${prec}f%%", 100*$ptr->[$j]->[$i]);
		}
		print "$buffer\n";
		$buffer = '';
	}
}

END {
	my $end_time = Time::HiRes::time();
	warn "Script completed in " . sprintf("%0.02f", ( $end_time - $start_time )) . " seconds.\n";
	exit 0;
}
