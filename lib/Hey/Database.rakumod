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


our sub find-x-by-name(Str $name, Str $table, DB::Connection $connection) returns Maybe[Hash] is export {
	my $sql = qq:to/END/;
		SELECT id, name from ? where name = ? LIMIT 1;
	END

	given $connection.query($sql, $table, $name).hash {
		when $_.elems > 0 {something($_)}
		default {nothing(Hash)}
	}
}
our sub find-things-by-ids(Array $ids, Str $table, DB::Connection $connection) returns Array is export {

	my $ids_string=$ids.join(', ');
	my $sql = qq:to/END/;
		SELECT * from $table where id in ($ids_string);
	END
	my $result = $connection.query($sql).hashes.Array;
	return $result;
}

our sub find-thing-ids-for-event(Int $event_id,
								 Str $singular_thing_type, # singular, E.g. project
								 Str $plural_thing_type,
								 DB::Connection $connection) returns Array is export {
	my $query_sql = qq:to/END/;
	SELECT $($singular_thing_type)_id FROM events_$($plural_thing_type)
	WHERE event_id = $event_id
	END

	return $connection.query($query_sql).arrays.Array;
}

our sub find-people-for-event(Hash $event_hash, DB::Connection $connection) returns Array is export {
	my $query_sql = qq:to/END/;
	select person_id from events_people where event_id = $event_hash<id>
	END
	my $person_ids = $connection.query($query_sql).arrays.Array;
	return $person_ids if $person_ids.elems == 0;
	return find-people-by-id($person_ids, $connection);
}

our sub find-tags-for-event(Hash $event_hash, DB::Connection $connection) returns Array is export {
	my $query_sql = qq:to/END/;
	select tag_id from events_tags where event_id = $event_hash<id>
	END
	my $tag_ids = $connection.query($query_sql).arrays.Array;
	return $tag_ids if $tag_ids.elems == 0;
	return find-tags-by-id($tag_ids, $connection);
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

our sub kill-person(Int $person_id, DB::Connection $connection) is export {
	# find events only associated with that person
	# at the moment events are ONLY associated with one person, so we can cheat
	my $sql = qq:to/END/;
	SELECT event_id from events_people
	WHERE person_id = $person_id
	END
	my @people_event_ids = $connection.query($sql).arrays.Array;
	return unless @people_event_ids.elems > 0;

	$sql = qq:to/END/;
	DELETE FROM events_people
	WHERE person_id = $person_id
	END
	my $count = $connection.query($sql);

	$sql = qq:to/END/;
	DELETE FROM events_tags
	WHERE event_id in (?)
	END
	$count = $connection.query($sql, @people_event_ids.join(', '));
	# just going to leave spurious tags

	$sql = qq:to/END/;
	DELETE FROM events
	WHERE id in (?)
	END
	$count = $connection.query($sql, @people_event_ids.join(', '));
}
our sub kill-event(Int $event_id, DB::Connection $connection) is export {
	# find events only associated with that person
	# at the moment events are ONLY associated with one person, so we can cheat

	my $sql = qq:to/END/;
	DELETE FROM events_people
	WHERE event_id = $event_id
	END
	my $count = $connection.query($sql);

	$sql = qq:to/END/;
	DELETE FROM events_tags
	WHERE event_id = $event_id
	END
	$count = $connection.query($sql);
	# just going to leave spurious tags

	$sql = qq:to/END/;
	DELETE FROM events
	WHERE id = $event_id
	END
	$count = $connection.query($sql);
}
