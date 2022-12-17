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



unit module Hey::Person;
use DB::SQLite;
use Definitely;
use Hey::Database;
use Hey::Event;

our sub find-people-for-event(Int $event_id, DB::Connection $connection) returns Array is export {
	my $person_ids = find-thing-ids-for-event($event_id, 'person', 'people', $connection);
	return $person_ids if $person_ids.elems == 0;
	return find-people-by-id($person_ids, $connection);
}

our sub find-people-by-id(Array $person_ids, DB::Connection $connection) returns Array is export {
	find-things-by-ids($person_ids, 'people', $connection)
}

# Takes in a person, returns the id of the newly created person
our sub create-person(Str $person, DB::Connection $connection) returns Hash is export {
	my $insert_sql = q:to/END/;
	INSERT INTO people (name) VALUES (?)
	END
	my $statement_handle = $connection.prepare($insert_sql);
	my $rows_changed = $statement_handle.execute([$person]);
	my $found_person_hash = find-person($person, $connection);
	return unwrap($found_person_hash, "Couldn't find the person I just created for $person");
}

our sub find-or-create-person(Str $person, DB::Connection $connection) returns Hash is export {
	my $lowercased_name = $person.lc;
	my $maybe_person = find-person($person, $connection);
	return $maybe_person.value if $maybe_person ~~ Some;
	return create-person($person, $connection);
}

our sub find-person(Str $person, DB::Connection $connection) returns Maybe[Hash] is export {
	find-x-by-name($person, 'people', $connection);
}

our sub bind-event-person(Int $event_id, Int $person_id, DB::Connection $connection) is export {
	unless is-event-personed($event_id, $person_id, $connection) {
		bind-x-to-event($event_id, $person_id, 'person', 'people', $connection)
	}
}

our sub is-event-personed(Int $event_id, Int $person_id, DB::Connection $connection) returns Bool is export {
	is-x-evented($event_id, $person_id, 'project', 'projects', $connection);
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

	$sql = qq:to/END/;
	DELETE FROM people
	WHERE id = $person_id
	END
	$count = $connection.query($sql);
}
