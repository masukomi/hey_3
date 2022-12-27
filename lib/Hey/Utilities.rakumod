unit module Hey::Utilities;
use Time::Duration;
use Listicles;
use Hey::Exceptions;

# Can't figure out how to export a constant so... methods it is.
our sub time-units() returns Array is export {
	<second seconds minute minutes hour hours day days week weeks month months year years>.Array;
}
our sub relative-time-regex returns Regex is export {
	/^ \d+ \s+ \w+ \s+ "ago"/
}
our sub time-regex returns Regex is export {
    /^ [(\d ** 1..2) '/' (\d ** 1..2) \s+]?  (\d ** 1..2) [ ":" (\d ** 2) ]?/;
}
# full ex  12         /    6                    3            :   35
#                                              04            :   30
#                                               4            :   30
#                                               4
# e.g. stop at 12/6 3:35
#      stop at 3:35
#      stop at 3


our sub midnightify(DateTime $dt) returns DateTime is export {
	$dt.earlier(
				[
				hours => $dt.hour,
				minutes => $dt.minute,
				seconds => $dt.second
				]
			)
}

our sub duration-string(Int $started_at, $ended_at) returns Str is export {
	return "ongoing" unless $ended_at ~~ Int;
	my $seconds = $ended_at - $started_at;
	return concise(duration($seconds));
}


# returns ("4", "minutes") or ()
sub ago-timer-args(@args) returns List {
	if (@args.elems > 2
			and @args[2] eq "ago"
			and @args[0].match(/^ \d+ $/)
			and time-units.includes(@args[1].lc)
		   ) {
		return [@args[0].Int, @args[1].Str.lc]
	}
	return [];
}
sub at-timer-args(@args) returns List {
	return () if @args.Array.is-empty;
	return () unless @args[0] eq 'at';
	my $match_result = @args[1..*].join(' ').match(time-regex);
	return () unless $match_result;
	# either
	# 3 (3 o'clock)
	# 3 30 (3:30)
	# 12 6 3 30 (12/6 3:30)
	return $match_result.list.grep({ $_ ~~ Match }).map({.Int}).List;
}

# TODO: modify this to return a hash
# I'm finding myself analyzing it by counting elements returned
# and that's a lot of magic numbers and potential failure points
# when we change this to support more things.
our sub extract-time-adjustment-args(@all_args) returns Array is export {
	my $ago_args = ago-timer-args(@all_args);
	return $ago_args.Array unless $ago_args.is-empty;
	my $at_timer_results =  at-timer-args(@all_args).Array; #might be empty
	return $at_timer_results;
}

# absolute time...
# if elems == 4 then 12/6 3:30  [12, 6, 3, 30]
# if elems == 2 then 3:30       [3, 30]
# if elems == 1 then 3          [3]
my sub hour-from-absolute-matches(@matches) returns Int {
	given @matches.elems {
		# month day hour minute
		when 4  { return @matches[2] }
		# hour minute
		when 1..2  { return @matches[0] }
		default { Hey::Exceptions::Exitable.new("unexpected number of time elements", 65).throw }
	}
}
my sub minutes-from-absolute-matches(@matches) returns Int {
	given @matches.elems {
		# month day hour minute
		when 4  { return @matches[3] }
		# hour minute
		when 2  { return @matches[1] }
		# just hour
		when 1  { return 0 }
		default { Hey::Exceptions::Exitable.new("unexpected number of time elements", 65).throw }
	}
}

my sub month-from-absolute-matches(@matches, DateTime $now) returns Int {
	return @matches[0] if @matches.elems == 4;
	return $now.month;
}
my sub day-from-absolute-matches(@matches, DateTime $now) returns Int {
	return @matches[1] if @matches.elems == 4;

	return $now.day-of-month;
}

our sub adjusted-date-time(DateTime $now, @adjustment_args, Int $started_at? ) returns DateTime is export {
	# @adjustment_args should be the output of extract-time-adjustment-args(@all_args)
	my $timer_adjustments = @adjustment_args;

	# no modifications necessary
	return $now if $timer_adjustments.is-empty;

	#ah well...
	#
	# relative time?

	if $timer_adjustments[1] ~~ Str {
		# n minutes/days/etc.
		return $now.earlier(
			[Pair.new($timer_adjustments[1], $timer_adjustments[0])]
		)
	}

	my $month = month-from-absolute-matches($timer_adjustments, $now);
	my $day = day-from-absolute-matches($timer_adjustments, $now);
	my $tweaked_hour_info = { hour => hour-from-absolute-matches($timer_adjustments),
							  yesterday => False };

	# don't like this magic number bs
	# there are 4 elems if we have 12/22 04:33 type times
	# these have to be assumed to be correct.
	if $timer_adjustments.elems != 4 {
		$tweaked_hour_info = hour-adjustments($now, $tweaked_hour_info<hour>);
	}
	# if it's January 1 and you need to backdate something to 12/31 you want it
	# to be recorded for last year not 12 months in the future.
	my $year =  $month <= $now.month ?? $now.year !! $now.year - 1;
	my $then = DateTime.new(
		year		=> $year,
		month		=> $month,
		day         => $day,
		hour		=> $tweaked_hour_info<hour>,
		minute		=> minutes-from-absolute-matches($timer_adjustments),
		second		=> 0,
		timezone	=> $now.timezone
	);

	my $tweaked_dt = $tweaked_hour_info<yesterday>
	         ?? $then.earlier(days => 1)
			 !! $then;
	return $tweaked_dt unless defined $started_at;
	return $tweaked_dt if $tweaked_dt.posix > $started_at;
	Hey::Exceptions::Exitable.new( message => "Error. I calculated that stop time as $tweaked_dt but that's before the start of "
	    ~ DateTime.new($started_at)
        ~ " either I screwed up or you entered a stop that preceeded the start. It was probably me.", exit_code => 65).throw;
}

my sub twenty-four-hour-hour(int $hour) returns Int {
	my $plus_12 = $hour + 12;
	return $hour if $plus_12 > 23;
	return $plus_12;
}
my sub hour-adjustments(DateTime $now, Int $hour) returns Hash {
	my %results = (
		hour => $hour,
		yesterday => False
	);

	# PLEASE REFACTOR THIS INTO SOMETHING MORE SANE
	# This just feels ugly.
	my $pre_noon = $now.hour < 12;
	if $pre_noon and $hour > $now.hour {
		%results<yesterday> = True;
		%results<hour> = twenty-four-hour-hour(%results<hour>);
	} elsif (! $pre_noon) and $hour < 12 {
		if ($hour <= ($now.hour - 12)) {
			# it's between 12PM and now
			%results<hour> = twenty-four-hour-hour(%results<hour>);
		}
		# otherwise
		# it's got to be morning
		# hour stays untouched
	}

	return %results;
}

