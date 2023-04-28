unit module Hey::Timer;

use Hey::Database;
use Hey::Event;
use Hey::Project;
use Hey::Tag;
use Hey::Utilities;
use Definitely;
use DB::SQLite;
use Prettier::Table;
use DateTime::Format;
use Time::Duration;
use Listicles;

our sub current-timers(DB::Connection $connection) returns Maybe[Array] is export {
	find-ongoing-events("timer", $connection);
}

# the return value here indicates if anything was displayed
our sub display-current-timers(DB::Connection $connection, Bool :$skip_if_none = True, Array :$provided_timers) returns Bool is export {
	my $timers = $provided_timers ?? $provided_timers !! current-timers($connection);
	return False if $timers ~~ None;
	$timers = $timers.value if $timers ~~ Some;
	return False if $timers.elems == 0 and $skip_if_none;
	for $timers.Array -> $timer_hash {
		$timer_hash<projects> = timer-projects($timer_hash<id>, $connection);
		$timer_hash<tags> = timer-tags($timer_hash<id>, $connection);
	}
	display-timers-as-table($timers, "Running Timers", False);
	return True;
}

our sub timers-since(Int $epoch_since, DB::Connection $connection, Str :$order='DESC') returns Array is export {
	find-events-since("timer", $epoch_since, $connection, order=>$order)
}

our sub timer-projects(Int $timer_id, DB::Connection $connection) returns Array is export {
	return find-projects-for-event($timer_id, $connection);
}
our sub timer-tags(Int $timer_id, DB::Connection $connection) returns Array is export {
	return find-tags-for-event($timer_id, $connection);
}

our sub timer-duration(Hash $timer_hash) returns Str is export {
	duration-string($timer_hash<started_at>, $timer_hash<ended_at>);
}


# assumes each hash has a <projects> key with an array of project hashes
our sub display-timers-as-table(@timer_hashes, $title, Bool $include_summary = True) is export {
	my $table = Prettier::Table.new(
		title => $title,
		field-names => ['ID', 'Started', 'Ended', 'Total', 'Projects', 'Tags'],
		align => %('Started' => 'l',
				   'Ended' => 'l',
				   'Total' => 'r',
				   'Projects' => 'l',
				   'Tags' => 'l')
	);
	my $total_seconds = 0;
	my @all_projects = [];
	my @all_tags = [];
	for @timer_hashes -> %timer_hash {
		my $dt = DateTime.new(%timer_hash<started_at>);
		my $ended_at_dt = %timer_hash<ended_at> ?? DateTime.new(%timer_hash<ended_at>) !! Nil;
		my @project_names = %timer_hash<projects>.map({$_<name>});
		my @tag_names = %timer_hash<tags>.map({$_<name>});
		$table.add-row([
							  %timer_hash<id>,
							  strftime("%a %m/%d %I:%M %p", $dt.local),
							  $ended_at_dt ?? strftime("%a %I:%M %p", $ended_at_dt.local) !! "",
							  timer-duration(%timer_hash),
							  @project_names.sort.join(", "),
							  @tag_names.sort.join(", ")
						  ]);

		# totals gathering ...
		@all_projects.push(@project_names);
		@all_tags.push(@tag_names);
		if %timer_hash<ended_at> ~~ Int {
			$total_seconds += (%timer_hash<ended_at> - %timer_hash<started_at>);
		}
	}

	if $include_summary {
		$table.add-row(["", "Summary",
						duration($total_seconds),
						@all_projects.flatten.sort.unique,
						@all_tags.flatten.sort.unique
					]);

	}
	say $table;
}

our sub display-timers-summary-as-table(@timer_hashes, $title) is export {

	my $table = Prettier::Table.new(
		title => $title,
		field-names => ['Project', 'Total Time'],
		align => %('Project' => 'l',
				'Total Time' => 'r')
	);

	my $total_seconds = 0;
	my %project_times = ();
	for @timer_hashes -> %timer_hash {
		# Running timers don't have an end-time; treat them as 0-length
		my $timer_seconds = %timer_hash<ended_at> ~~ Int:D
			?? (%timer_hash<ended_at> - %timer_hash<started_at>)
			!! 0;
		$total_seconds += $timer_seconds;
		for %timer_hash<projects>.map({$_<name>}) -> $project {
			%project_times.EXISTS-KEY($project)
				?? (%project_times{$project} += $timer_seconds)
				!! (%project_times{$project} = $timer_seconds);
	    }
	}
	for %project_times.pairs.sort({.key}) -> $pair {
		my $seconds = $pair.value;
		my $time_string = concise(duration($seconds));
		if $seconds > 3600 { # seconds in an hour 
			$time_string ~= " (" ~ sprintf("%.2f", ($seconds / 3600)) ~ " hrs)" ;
		}

		$table.add-row([$pair.key, $time_string]);
	}
	my $project_chars = %project_times.keys.map({.chars}).max;
	$table.add-row([("━" x $project_chars) , "━━━━━━━"]);
	$table.add-row(['All…', concise(duration($total_seconds))]);
	my $last_with_end =  @timer_hashes.grep({$_<ended_at> ~~ Int}).tail;
	my $start_to_end = $last_with_end<ended_at> ~~ Int:D
		?? $last_with_end<ended_at> - @timer_hashes.head<started_at>
		!! 0;
	my $unaccounted_seconds = $start_to_end - $total_seconds;
	$table.add-row(['Unaccounted…', concise(duration($unaccounted_seconds))]);


	say $table;
}

our sub populate-timer-relations(Hash $timer, DB::Connection $connection) returns Hash is export {
	$timer<projects> = timer-projects($timer<id>, $connection);
	$timer<people> = [];
	$timer<tags> = timer-tags($timer<id>, $connection);
	return $timer;
}
