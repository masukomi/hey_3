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



unit module Hey::Project;
use DB::SQLite;
use Definitely;
use Hey::Database;
use Hey::Event;


# Project
# bind-event-project
# create-project
# find-or-create-project
# find-project
# find-projects-by-id
# find-projects-for-event
# is-event-projected

our sub bind-event-project(Int $event_id, Int $project_id, DB::Connection $connection) is export {
	unless is-event-projected($event_id, $project_id, $connection) {
		bind-x-to-event($event_id, $project_id, 'project', 'projects', $connection);
	}
}

our sub is-event-projected(Int $event_id, Int $project_id, DB::Connection $connection) returns Bool is export {
	is-x-evented($event_id, $project_id, 'project', 'projects', $connection);
}


# Takes in a project name, returns the id of the newly created project
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

our sub find-project(Str $project, DB::Connection $connection) returns Maybe[Hash] is export {
	find-x-by-name($project, 'projects', $connection);
}

our sub find-projects-by-id(Array $project_ids, DB::Connection $connection) returns Array is export {
	find-things-by-ids($project_ids, 'projects', $connection);
}

our sub find-projects-for-event(Int $event_id, DB::Connection $connection) returns Array is export {
	my $project_ids = find-thing-ids-for-event($event_id, 'project', 'projects', $connection);
	return $project_ids if $project_ids.elems == 0;
	return find-projects-by-id($project_ids, $connection);
}
