unit module Hey::Interruption;

use Hey::Database;
use Definitely;
use DB::SQLite;
use Prettier::Table;
use Listicles;
use DateTime::Format;


our sub interruptions-since(
	Int $epoch_since,
	DB::Connection $connection
) returns Array is export {
	find-events-since("interruption", $epoch_since, $connection)
}

our sub interruption-people(
	Hash $interruption_hash,
	DB::Connection $connection
) returns Array is export {
	return find-people-for-event($interruption_hash,
								$connection);
}

our sub interruption-projects(Hash $interruption_hash, DB::Connection $connection) returns Array is export {
	return find-projects-for-event($interruption_hash,
								$connection);
}

# TODO this should be extracted out to Event as event-tags
our sub interruption-tags(Hash $interruption_hash, DB::Connection $connection) returns Array is export {
	return find-tags-for-event($interruption_hash, $connection);
}


# assumes each hash has a <projects> key with an array of project hashes
our sub display-interruptions-as-table(@interruption_hashes, $title, Bool $include_summary = True) is export {
	my @sorted_interruptions = @interruption_hashes.sort({$^a<started_at> cmp $^b<started_at>});
	my $table = Prettier::Table.new(
		title => $title,
		field-names => ['ID', 'Started', 'People', 'Projects', 'Tags'],
		align => %('Started' => 'l',
				   'People' => 'l',
				   'Projects' => 'l',
				   'Tags' => 'l')
	);
	my @all_projects = [];
	my @all_people = [];
	my @all_tags = [];
	for @sorted_interruptions -> %interruption_hash {
		my $dt = DateTime.new(%interruption_hash<started_at>);
		my @project_names = %interruption_hash<projects>.map({$_<name>});
		my @people_names = %interruption_hash<people>.map({$_<name>});
		my @tag_names = %interruption_hash<tags>.map({$_<name>});
		$table.add-row([
							  %interruption_hash<id>,
							  strftime("%m/%d %H:%M", $dt.local),
							  @people_names.join(", "),
							  @project_names.join(", "),
							  @tag_names.join(", ")
						  ]);

		# totals gathering ...
		@all_projects.push(@project_names);
		@all_people.push(@people_names);
		@all_tags.push(@tag_names);
	}

	if $include_summary {
		$table.add-row(["", "Summary",
						@all_people.flatten.sort.unique,
						@all_projects.flatten.sort.unique,
						@all_tags.flatten.sort.unique
					]);

	}
	say $table;
}
