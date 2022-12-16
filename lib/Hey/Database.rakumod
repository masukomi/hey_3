# Copyright (C) 2022 Kay Rhodes (a.k.a masukomi)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# YOUR CONTRIBUTIONS, FINANCIAL, OR CODE, TO MAKING THIS A BETTER TOOL
# ARE GREATLY APPRECIATED. See https://interrupttracker.com



unit module Hey::Database;
use DB::SQLite;
use Definitely;


# Events
# find-last-event
# create-event
# stop-event
# find-ongoing-events
#

#= a list of ongoing events ordered by oldest first
our sub find-ongoing-events(Str $event_type, DB::Connection $connection) returns Maybe[Array] is export {

	my $sql = q:to/END/;
		SELECT * from events
		where ended_at is null
		and type = ?
		order by started_at ASC
	END

	given $connection.query($sql, $event_type).hashes {
		when $_.elems > 0 {
			something($_.Array)
		}
		default {nothing(Array);}
	}
}
our sub find-events-since(Str $type, Int $epoch_since, DB::Connection $connection) returns Array is export {
	my $sql = q:to/END/;
		SELECT * from events
		WHERE type = ?
	          AND started_at >= ?
		order by id DESC;
	END

	$connection.query($sql, $type, $epoch_since).hashes.Array;
}
our sub find-last-event(Str $type, DB::Connection $connection) returns Maybe[Hash] is export {
	my $sql = q:to/END/;
		SELECT * from events
		WHERE type = ?
		order by id DESC LIMIT 1;
	END

	given $connection.query($sql, $type).hash {
		when $_.elems > 0 {something($_)}
		default {nothing(Hash);}
	}
}

our sub create-event(DB::Connection $connection,
					 Str $event_type,
					 Int $started_at
					) returns Hash is export {
	my $insert_sql = q:to/END/;
	INSERT INTO events (started_at, type) VALUES (?, ?)
	END
	my $statement_handle = $connection.prepare($insert_sql);
	my $rows_changed = $statement_handle.execute([$started_at, $event_type]);
	return find-last-event($event_type, $connection).value; # there damn well better be one
}

our sub stop-specific-event(Int $id, Int $stopped_at, DB::Connection $connection) is export {
	my $update_sql = qq:to/END/;
	UPDATE events set ended_at = $stopped_at
	WHERE id = $id
	END
	my $statement_handle = $connection.prepare($update_sql);
	$statement_handle.execute(); # or go boom
	return True;
}

our sub stop-event(Int $stopped_at,
				   DB::Connection $connection,
				  ) returns Bool is export {
	my $maybe_last_event = find-last-event("timer", $connection);
	return False unless $maybe_last_event ~~ Some;

	my $last_event_id = $maybe_last_event.value<id>;
	stop-specific-event($last_event_id, $stopped_at, $connection);
}

#TODO: the 3 project methods are copy-pasta of the similar tag methods.
# REFACTOR


# Project
# find-or-create-project
# find-project
# create-project
# bind-event-project

our sub bind-event-project(Int $event_id, Int $project_id, DB::Connection $connection) is export {

	unless is-event-projected($event_id, $project_id, $connection) {
		my $insert_sql = qq:to/END/;
		INSERT INTO events_projects (event_id, project_id)
		VALUES ($event_id, $project_id);
		END
		$connection.prepare($insert_sql).execute();
	}
}

our sub is-event-projected(Int $event_id, Int $project_id, DB::Connection $connection) returns Bool is export {
	my $query_sql = qq:to/END/;
	SELECT count(*) from events_projects
	WHERE
	  event_id = $event_id
	  AND project_id = $project_id
	END
	my $count = $connection.query($query_sql).value;
	return $count > 0;
}



# Takes in a project, returns the id of the newly created project
our sub create-project(Str $project, DB::Connection $connection) returns Hash is export {
	my $insert_sql = q:to/END/;
	INSERT INTO projects (name) VALUES (?)
	END
	my $statement_handle = $connection.prepare($insert_sql);
	my $rows_changed = $statement_handle.execute([$project.subst(/^ "@"/, "")]);
	my $found_project_hash = find-project($project, $connection);
	return unwrap($found_project_hash, "Couldn't find the project I just created for $project");
}

our sub find-or-create-project(Str $project, DB::Connection $connection) returns Hash is export {
	my $lowercased_name = $project.lc;
	my $maybe_project = find-project($project, $connection);
	return $maybe_project.value if $maybe_project ~~ Some;
	return create-project($project, $connection);
}

our sub find-project(Str $project,DB::Connection $connection) returns Maybe[Hash] is export {
	my $sql = q:to/END/;
		SELECT id, name from projects where name = ? LIMIT 1;
	END

	given $connection.query($sql, $project).hash {
		when $_.elems > 0 {something($_)}
		default {nothing(Hash)}
	}
}

our sub find-projects-for-event(Hash $event_hash, DB::Connection $connection) returns Array is export {
	my $query_sql = qq:to/END/;
	select project_id from events_projects where event_id = $event_hash<id>
	END
	my $project_ids = $connection.query($query_sql).array.Array;
	return $project_ids if $project_ids.elems == 0;
	return find-projects-by-id($project_ids, $connection);
}

our sub find-people-for-event(Hash $event_hash, DB::Connection $connection) returns Array is export {
	my $query_sql = qq:to/END/;
	select person_id from events_people where event_id = $event_hash<id>
	END
	my $person_ids = $connection.query($query_sql).array.Array;
	return $person_ids if $person_ids.elems == 0;
	return find-people-by-id($person_ids, $connection);
}

our sub find-tags-for-event(Hash $event_hash, DB::Connection $connection) returns Array is export {
	my $query_sql = qq:to/END/;
	select tag_id from events_tags where event_id = $event_hash<id>
	END
	my $tag_ids = $connection.query($query_sql).array.Array;
	return $tag_ids if $tag_ids.elems == 0;
	return find-tags-by-id($tag_ids, $connection);
}

our sub find-projects-by-id(Array $project_ids, DB::Connection $connection) returns Array is export {
	my $sql = q:to/END/;
		SELECT id, name from projects where id in (?);
	END

	return $connection.query($sql, $project_ids.join(", ")).hashes.Array;
}
our sub find-people-by-id(Array $person_ids, DB::Connection $connection) returns Array is export {
	my $sql = q:to/END/;
		SELECT id, name from people where id in (?);
	END

	return $connection.query($sql, $person_ids.join(", ")).hashes.Array;
}


our sub find-tags-by-id(Array $tag_ids, DB::Connection $connection) returns Array is export {
	my $sql = q:to/END/;
		SELECT id, name from tags where id in (?);
	END

	return $connection.query($sql, $tag_ids.join(", ")).hashes.Array;
}




# TAGS
# find-or-create-tag
# find-tag
# create-tag
# tag-event


our sub tag-event(Str $tag, Int $event_id, DB::Connection $connection) is export {
	my $tag_hash = find-or-create-tag($tag.lc, $connection);
	unless is-thing-tagged($event_id, $tag_hash<id>, "tag", $connection) {
		my $insert_sql = qq:to/END/;
		INSERT INTO events_tags (event_id, tag_id)
		VALUES ($event_id, $tag_hash<id>);
		END

		$connection.prepare($insert_sql).execute();
	}
}
our sub tag-project(Str $tag, Int $project_id, DB::Connection $connection) is export {
	my $tag_hash = find-or-create-tag($tag.lc, $connection);
	unless is-thing-tagged($project_id, $tag_hash<id>, "project", $connection) {
		my $insert_sql = qq:to/END/;
		INSERT INTO projects_tags (project_id, tag_id)
		VALUES ($project_id, $tag_hash<id>);
		END

		$connection.prepare($insert_sql).execute();
	}
}

our sub is-thing-tagged(Int $event_id, Int $tag_id, Str $thing_type, DB::Connection $connection) returns Bool is export {
	my $query_sql = qq:to/END/;
	SELECT count(*) from events_tags
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
	return find-tag($tag, $connection).value;
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

	given $connection.query($sql, name=> $tag).hash {
		when $_.elems > 0 {something($_)}
		default {nothing(Hash)}
	}
}



## People
##
# Takes in a person, returns the id of the newly created person
our sub create-person(Str $person, DB::Connection $connection) returns Hash is export {
	my $insert_sql = q:to/END/;
	INSERT INTO people (name) VALUES (?)
	END
	my $statement_handle = $connection.prepare($insert_sql);
	my $rows_changed = $statement_handle.execute([$person.subst(/^ "@"/, "")]);
	my $found_person_hash = find-person($person, $connection);
	return unwrap($found_person_hash, "Couldn't find the person I just created for $person");
}

our sub find-or-create-person(Str $person, DB::Connection $connection) returns Hash is export {
	my $lowercased_name = $person.lc;
	my $maybe_person = find-person($person, $connection);
	return $maybe_person.value if $maybe_person ~~ Some;
	return create-person($person, $connection);
}

our sub find-person(Str $person,DB::Connection $connection) returns Maybe[Hash] is export {
	my $sql = q:to/END/;
		SELECT id, name from people where name = ? LIMIT 1;
	END

	given $connection.query($sql, $person).hash {
		when $_.elems > 0 {something($_)}
		default {nothing(Hash)}
	}
}
our sub bind-event-person(Int $event_id, Int $person_id, DB::Connection $connection) is export {

	unless is-event-personed($event_id, $person_id, $connection) {
		my $insert_sql = qq:to/END/;
		INSERT INTO events_people (event_id, person_id)
		VALUES ($event_id, $person_id);
		END
		$connection.prepare($insert_sql).execute();
	}
}

our sub is-event-personed(Int $event_id, Int $person_id, DB::Connection $connection) returns Bool is export {
	my $query_sql = qq:to/END/;
	SELECT count(*) from events_people
	WHERE
	  event_id = $event_id
	  AND person_id = $person_id
	END
	my $count = $connection.query($query_sql).value;
	return $count > 0;
}
