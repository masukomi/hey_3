unit module Hey::Database;
use DB::SQLite;
use Definititely;


# Events
# find-last-event
# create-event
# stop-event
our sub find-last-event(DB::Connection $connection) returns Maybe[Hash] {
	my $sql = q:to/END/;
		SELECT * from events order by started_at DESC LIMIT 1;
	END

	given $connection.query($sql).hash;
	when $_.elems > 0 {
		something($_);
	}
	default {
		nothing(Hash)
	}
}

our sub create-event(DB::Connection $connection,
					 Str $event_type,
					 DateTime $started_at = DateTime.now().posix()
					) returns Hash {
	my $insert_sql = q:to/END/;
	INSERT INTO events (started_at, type) VALUES (?, ?)
	END
	my $statement_handle = $connection.prepare($insert_sql);
	my $rows_changed = $statement_handle.execute([$started_at, $event_type]);
	return find-last-event($connection).value; # there damn well better be one
}


our sub stop-event(DB::Connection $connection,
				   DateTime $stopped_at DateTime.now().posix()
				  ) return Bool {
	my $maybe_last_event = find-last-event($connection);
	return False unless $last_event ~~ Some;

	my $last_event_id = $last_event.value<id>;
	my $update_sql = qq:to/END/;
	UPDATE events set stopped_at = $stopped_at
	END
	my $statement_handle = $connection.prepare($update_sql);
	my $statement_handle.execute(); # or go boom
	return True;
}

#TODO: the 3 project methods are copy-pasta of the similar tag methods.
# REFACTOR


# Project
# find-or-create-project
# find-project
# create-project
# bind-event-project
#
our sub bind-event-project(Int $event_id, Int $project_id, DB::Connection $connection) {
	unless is-event-projected($event_id, $tag_hash<id>, "tag") {
		my $insert_sql = qq:to/END/;
		INSERT INTO events_projects (event_id, project_id)
		VALUES ($event_id, $project_id);
		END
		$connection.prepare($insert_sql).execute();
	}
}

our sub is-event-projected(Int $event_id, Int $project_id) returns Bool {
	my $query_sql = qq:to/END/;
	SELECT count(*) from event_tags
	WHERE
	  event_id = $event_id
	  AND project_id = $project_id
	END
	my $count = $connection.query($query_sql).value;
	return $count > 0;
}



our sub tag-project(Str $tag, Int $project_id, DB::Connection $connection) {


# Takes in a project, returns the id of the newly created project
our sub create-project(Str $project, DB::Connection $connection) returns Hash is export {
	my $insert_sql = q:to/END/;
	INSERT INTO projects (name) VALUES (?)
	END
	my $statement_handle = $connection.prepare($insert_sql);
	my $rows_changed = $statement_handle.execute([$project]);
	return find-project($project);
}

our sub find-or-create-project(Str $project, DB::Connection $connection) returns Hash is export {
	my $lowercased_name = $project.lc;
	my $maybe_project = find-project($project, $connection);
	return $maybe_project.value if $maybe_project ~~ Some;
	return create-project($project, $connection);
}

our sub find-project(Str $project,DB::Connection $connection) returns Maybe[Hash] is export {
	my $sql = q:to/END/;
		SELECT id, name from projects where name = $name LIMIT 1;
	END

	given $connection.query($sql, name=> $project).hash;
	when $_.elems > 0 {
		something($_);
	}
	default {
		nothing(Hash)
	}
}




# TAGS
# find-or-create-tag
# find-tag
# create-tag
# tag-event


our sub tag-event(Str $tag, Int $event_id, DB::Connection $connection) {
	my $tag_hash = $find-or-create-tag($tag.lc, $connection);
	unless is-thing-tagged($event_id, $tag_hash<id>, "tag") {
		my $insert_sql = qq:to/END/;
		INSERT INTO events_tags (event_id, tag_id)
		VALUES ($event_id, $tag_hash<id>);
		END

		$connection.prepare($insert_sql).execute();
	}
}
our sub tag-project(Str $tag, Int $project_id, DB::Connection $connection) {
	my $tag_hash = $find-or-create-tag($tag.lc, $connection);
	unless is-thing-tagged($project_id, $tag_hash<id>, "project") {
		my $insert_sql = qq:to/END/;
		INSERT INTO projects_tags (project_id, tag_id)
		VALUES ($project_id, $tag_hash<id>);
		END

		$connection.prepare($insert_sql).execute();
	}
}

our sub is-thing-tagged(Int $event_id, Int $tag_id, Str $thing_type) returns Bool {
	my $query_sql = qq:to/END/;
	SELECT count(*) from event_tags
	WHERE
	  $($thing_type)_id = $event_id
	  AND tag_id = $tag_id
	END
	my $count = $connection.query($query_sql).value;
	return $count > 0;
}

# Takes in a tag, returns the id of the newly created tag
our sub create-tag(Str $tag, DB::Connection $connection) returns Hash is export {
	my $insert_sql = q:to/END/;
	INSERT INTO tags (name) VALUES (?)
	END
	my $statement_handle = $connection.prepare($insert_sql);
	my $rows_changed = $statement_handle.execute([$tag]);
	return find-tag($tag);
}

our sub find-or-create-tag(Str $tag, DB::Connection $connection) returns Hash is export {
	my $lowercased_name = $tag.lc;
	my $maybe_tag = find-tag($tag, $connection);
	return $maybe_tag.value if $maybe_tag ~~ Some;
	return create-tag($tag, $connection);
}

our sub find-tag(Str $tag,DB::Connection $connection) returns Maybe[Hash] is export {
	my $sql = q:to/END/;
		SELECT id, name from tags where name = $name LIMIT 1;
	END

	given $connection.query($sql, name=> $tag).hash;
	when $_.elems > 0 {
		something($_);
	}
	default {
		nothing(Hash)
	}
}
