#!/usr/bin/env sh

source ./test_suite_management.sh

if [ ! -e hey ]; then
	cd ../
	if [ ! -e bin/hey ]; then
		echo "Run me from within the bash_unit_tests directory"
		exit 1
	fi
fi


HEY_INVOCATION="raku -I lib bin/hey"

test_01_usage () {
  #assert_equals expected actual message
  hey_usage=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION -v 2>&1 | head -n1)
  assert_equals "Usage:" \
	  "$hey_usage" \
	  "should provide usage without args"

  assert_status_code 2 "$HEY_INVOCATION -v > /dev/null 2>&1"
}

test_02_confirm_no_db(){
	assert "test ! -e $DB_LOCATION"
}

test_03_log_empty(){
	no_content_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION log 1 day)
	assert_equals "No timers found" "$no_content_output"
}
test_04_log-interrupts_empty(){
	no_content_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION log-interrupts 1 day)
	assert_equals "No interruptions found" "$no_content_output"
}

## Interruptions
test_05_add-interrupt(){
	new_interrupt_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION bob)
	assert_equals "Gotcha. 'twas bob" "$new_interrupt_output"
	event_count=$(sqlite3 $DB_LOCATION "select count(*) from events")
	assert_equals "1" $event_count;
}
test_06_add-interrupt_w_proj_and_tag(){
	new_interrupt_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION bob @foo +bar)
	assert_equals "Gotcha. 'twas bob" "$new_interrupt_output"
	tag_count=$(sqlite3 $DB_LOCATION "select count(*) from tags where name='bar'")
	assert_equals "1" $tag_count;
	project_count=$(sqlite3 $DB_LOCATION "select count(*) from projects where name='foo'")
	assert_equals "1" $project_count;
}
test_07_interrupt_log(){
	output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION log-interrupts 1 day)
	lines=$(echo "$output" | wc -l);
	assert_equals "9" $lines
	title_lines=$(echo "$output" | grep "All Interruptions" | wc -l)
	assert_equals "1" $title_lines
}

test_08_kill_person(){
	original_tag_count=$(sqlite3 $DB_LOCATION "select count(*) from tags where name='bar'")
	original_project_count=$(sqlite3 $DB_LOCATION "select count(*) from projects where name='foo'")

	kill_interrupt_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION kill bob)
	assert_equals "bob is dead. Long live bob." "$kill_interrupt_output"
	new_tag_count=$(sqlite3 $DB_LOCATION "select count(*) from tags where name='bar'")
	new_project_count=$(sqlite3 $DB_LOCATION "select count(*) from projects where name='foo'")

	assert_equals $original_tag_count $new_tag_count \
		"number of tags shouldn't have changed when killing person"
	assert_equals $original_project_count $new_project_count \
		"number of projects shouldn't have changed when killing person"
	person_count=$(sqlite3 $DB_LOCATION "select count(*) from people where name='bob'")
	assert_equals 0 $person_count "bob has escaped death!"

}

# we're asking for a 1 day log so nothing from yesterday should be
# in it
test_08_old_interrupt_not_in_log(){
	new_interrupt_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION bob 24 hours ago)
	assert_equals "Gotcha. 'twas bob" "$new_interrupt_output"
	output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION log-interrupts 1 day );
	lines=$(echo "$output" | wc -l);
	assert_equals "9" $lines
}

# we've just added interrupts so nothing should be in the timer
# log yet
test_09_timer_log_still_empty(){
	no_content_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION log 1 day)
	assert_equals "No timers found" "$no_content_output"
}

test_10_start_timer(){

	new_timer_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION start 4 minutes ago @project_x @project_y +tag1 +tag2)
	timer_id=$(echo "$new_timer_output" | sed -e "s/.*(//" -e "s/).*//")

	# strip the id and the time
	non_specific_response=$(echo "$new_timer_output" | sed -e "s/(.*) //" -e "s/ at .*/ at/")
	assert_equals "Started Timer for project_x, project_y at" "$non_specific_response"
	# check that the projects were created
	project_count=$(sqlite3 $DB_LOCATION "select count(*) from projects where name='project_x' OR name='project_y'")
	assert_equals "2" $project_count "wrong number of projects";

	# check that the tags were created
	tag_count=$(sqlite3 $DB_LOCATION "select count(*) from tags where name='tag1' OR name='tag2'")
	assert_equals "2" $tag_count "wrong number of tags";

	#check that the projects were bound to the event
	bound_project_count=$(sqlite3 $DB_LOCATION "select count(*) from events_projects where event_id = $timer_id")
	assert_equals "2" $bound_project_count "wrong number of associated projects";

	#check that the tags were bound to the event
	bound_tag_count=$(sqlite3 $DB_LOCATION "select count(*) from events_tags where event_id = $timer_id")
	assert_equals "2" $bound_tag_count "wrong number of associated tags";

	# check that the timer has a start date and no end date
	date_check=$(sqlite3 $DB_LOCATION "select started_at, ended_at from events where id = $timer_id")
	# a ten digit number followed by a pipe and then nothing
	assert_matches '^[0-9]{10}\|$' "$date_check" "unexpected start / end date";
}

test_11_running(){
	running_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION running | grep ongoing)

	assert_matches ".*ongoing.*" "$running_output"
}

test_12_timer_stop(){
	stop_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION stop)
	assert_matches "Stopped [0-9]+ at .* [0-9]{1,2}:[0-9]{2}.* (@.*) after 4m[0-9]{1,2}s" "$stop_output"
	date_check=$(sqlite3 $DB_LOCATION "select started_at, ended_at from events order by id DESC limit 1")
	# test that the stop got recorded
	# a ten digit start and end time separated by a pipe character
	assert_matches '^[0-9]{10}\|[0-9]{10}$' "$date_check" "unexpected start / end date";
}

test_13_nevermind(){
	new_timer_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION start @foo)
	timer_id=$(echo "$new_timer_output" | sed -e "s/.*(//" -e "s/).*//")
	nevermind_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION nevermind)
	assert_equals "We shall never speak of it again." "$nevermind_output"

	killed_timer_count=$(sqlite3 $DB_LOCATION "select count(*) from events where id = $timer_id")
	assert_equals "0" $killed_timer_count "'nevermind'ing a timer didn't delete it";
}

### TODO
# Come up with a good way to test the relative and absolute backdating.
# Note that it's handled in the same place so we don't have to test it
# separately for timers & interrupts, at least not in detail.
# We _do_ need to test that it's still wired up for start, stop, and
# interrupt
#
# the following are just basic sanity checks to make sure that
# things don't blow up. They don't test the accuracy of the data.
#


test_14_start_at_hour() {
	XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION start at 4 @foo > /dev/null
	assert_equals 0 $?
	XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION nevermind > /dev/null
}
test_15_start_at_time() {
	XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION start at 4:30 @foo > /dev/null
	assert_equals 0 $?
	XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION nevermind > /dev/null
}
test_16_start_at_date_and_time() {
	XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION start at 12/15 4:30 @foo > /dev/null
	assert_equals 0 $?
	XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION nevermind > /dev/null
}

# when you start multiple timers it should give you a heads-up about running
# ones whenever there is more than 1
test_17_start_multiple_timers_table() {
	first_timer_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION start 4:30 @first)
	timer_id=$(echo "$new_timer_output" | sed -e "s/.*(//" -e "s/).*//")
	second_timer_output=$(XDG_DATA_HOME=$XDG_DATA_HOME $HEY_INVOCATION start 4:30 @second)
	still_first=$(echo "$second_timer_output" | grep "first" | wc -l)
    assert_equals 1 $still_first
	multiple_timers_note=$(echo "$second_timer_output" | grep "multiple running timers" | wc -l)
    assert_equals 1 $multiple_timers_note
}
