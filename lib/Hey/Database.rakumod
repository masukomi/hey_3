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
		SELECT id, name from $table where name = ? LIMIT 1;
	END
    #  you can't specify a table name with a ? in the current driver

	given $connection.query($sql, $name).hash {
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
