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



unit module Hey::Event;
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
our sub find-event-by-id(Int $id, Str $type, DB::Connection $connection) returns Maybe[Hash] is export {
	my $sql = qq:to/END/;
	SELECT * FROM events
	WHERE id = $id
	AND type = ?
	END
	given $connection.query($sql, $type).hash {
		when .elems > 0 {something($_)}
		default {nothing(Hash)}
	}

}

our sub find-events-since(Str $type, Int $epoch_since, DB::Connection $connection, Str :$order='DESC') returns Array is export {
	my $sql = qq:to/END/;
		SELECT * from events
		WHERE type = ?
	          AND started_at >= ?
		order by id $order;
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

our sub is-x-evented(Int $event_id, Int $x_id, Str $x_singular, Str $x_plural, DB::Connection $connection) returns Bool  is export {
	my $query_sql = qq:to/END/;
	SELECT count(*) from events_$($x_plural)
	WHERE
	  event_id = $event_id
	  AND $($x_singular)_id = $x_id
	END
	my $count = $connection.query($query_sql).value;
	return $count > 0;
}
our sub bind-x-to-event(Int $event_id, Int $x_id, Str $x_singular, Str $x_plural, DB::Connection $connection) is export {
	my $insert_sql = qq:to/END/;
	INSERT INTO events_$($x_plural) (event_id, $($x_singular)_id)
	VALUES ($event_id, $x_id);
	END
	$connection.prepare($insert_sql).execute();
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
