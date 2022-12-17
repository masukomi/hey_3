unit module Hey::Timer;

use Hey::Database;
use Hey::Event;
use Hey::Project;
use Hey::Tag;
use Definitely;
use DB::SQLite;
use Prettier::Table;
use DateTime::Format;
use Time::Duration;
use Listicles;

our sub current-timers(DB::Connection $connection) returns Maybe[Array] is export {
	find-ongoing-events("timer", $connection);
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


# assumes each hash has a <projects> key with an array of project hashes
our sub display-timers-as-table(@timer_hashes, $title, Bool $include_summary = True) is export {
	my $table = Prettier::Table.new(
		title => $title,
		field-names => ['ID', 'Started', 'Total', 'Projects', 'Tags'],
		align => %('Started' => 'l',
				   'Total' => 'r',
				   'Projects' => 'l',
				   'Tags' => 'l')
	);
	my $total_seconds = 0;
	my @all_projects = [];
	my @all_tags = [];
	for @timer_hashes -> %timer_hash {
		my $dt = DateTime.new(%timer_hash<started_at>);
		my @project_names = %timer_hash<projects>.map({$_<name>});
		my @tag_names = %timer_hash<tags>.map({$_<name>});
		$table.add-row([
							  %timer_hash<id>,
							  strftime("%m/%d %I:%M %p", $dt.local),
							  total-string(%timer_hash<started_at>,
										  %timer_hash<ended_at>),
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

our sub total-string(Int $started_at, $ended_at) {
	return "ongoing" unless $ended_at ~~ Int;
	my $seconds = $ended_at - $started_at;
	return concise(duration($seconds));

}
