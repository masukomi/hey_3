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



unit module Hey::Tag;
use DB::SQLite;
use Definitely;
use Hey::Database;
use Hey::Event;


# TAGS
# create-tag
# find-or-create-tag
# find-tag
# find-tags-by-id
# find-tags-for-event
# is-x-tagged
# tag-event
# tag-project
# tag-x

# Takes in a tag, returns the id of the newly created tag
our sub create-tag(Str $tag, DB::Connection $connection) returns Hash is export {
	my $insert_sql = q:to/END/;
	INSERT INTO tags (name) VALUES (?)
	END
	my $statement_handle = $connection.prepare($insert_sql);
	my $rows_changed = $statement_handle.execute([$tag.subst(/^ "+"/, "")]);
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

our sub find-tags-by-id(Array $tag_ids, DB::Connection $connection) returns Array is export {
	find-things-by-ids($tag_ids, 'tags', $connection);
}

our sub find-tags-for-event(Int $event_id, DB::Connection $connection) returns Array is export {
    my $tag_ids = find-thing-ids-for-event($event_id, 'tag', 'tags', $connection);
	return $tag_ids if $tag_ids.elems == 0;
	return find-tags-by-id($tag_ids, $connection);
}


# assumess table name of <x_plural>_tags
our sub is-x-tagged(Int $x_id, Int $tag_id, Str $x_singular, Str $x_plural, DB::Connection $connection) returns Bool is export {
	my $query_sql = qq:to/END/;
	SELECT count(*) from $($x_plural)_tags
	WHERE
	  $($x_singular)_id = $x_id
	  AND tag_id = $tag_id
	END
	my $count = $connection.query($query_sql).value;
	return $count > 0;
}



our sub tag-event(Str $tag, Int $event_id, DB::Connection $connection) is export {
	my $tag_hash = find-or-create-tag($tag.lc, $connection);
	unless is-x-tagged($event_id, $tag_hash<id>, 'event', 'events', $connection) {
		tag-x($tag_hash<id>, $event_id, 'event', 'events', $connection);
	}
}

#NOTE not actually using this... yet
our sub tag-project(Str $tag, Int $project_id, DB::Connection $connection) is export {
	my $tag_hash = find-or-create-tag($tag.lc, $connection);
	unless is-x-tagged($project_id, $tag_hash<id>, 'project', 'projects', $connection) {
		tag-x($tag_hash<id>, $project_id, 'project', 'projects', $connection);
	}
}

# assumes an <x_plural>_tags table
our sub tag-x(Int $tag_id, Int $x_id, Str $x_singular, Str $x_plural, DB::Connection $connection) is export {
	my $insert_sql = qq:to/END/;
	INSERT INTO $($x_plural)_tags ($($x_singular)_id, tag_id)
	VALUES ($x_id, $tag_id);
	END

	$connection.prepare($insert_sql).execute();
}
