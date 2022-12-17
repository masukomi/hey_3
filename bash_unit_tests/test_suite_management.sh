#!/usr/bin/env sh

setup_suite() {

	XDG_DATA_HOME=$(pwd)"/bash_unit_tests/TESTING_XDG_DATA_HOME";
	XDG_CONFIG_HOME=$(pwd)"/bash_unit_tests/TESTING_XDG_CONFIG_HOME";
	echo ""
	echo "XDG_DATA_HOME: $XDG_DATA_HOME"
	rm -rf $XDG_DATA_HOME 2>&1 > /dev/null
	rm -rf $XDG_CONFIG_HOME 2>&1 > /dev/null
	mkdir -p $XDG_DATA_HOME
	mkdir -p $XDG_CONFIG_HOME
	TEST_DATA_DIR=$(pwd)"/bash_unit_tests/test_data"
	DB_LOCATION=$XDG_DATA_HOME"/hey/hey.db"

}


teardown_suite() {
	rm -rf $XDG_DATA_HOME
	rm -rf $XDG_CONFIG_HOME
	echo "DONE";

}

delete_db() {
	rm -rf $DB_LOCATION 2>&1 > /dev/null
}
