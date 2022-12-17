unit module Hey::Utilities;

our sub midnightify(DateTime $dt) returns DateTime is export {
	$dt.earlier(
				[
				hours => $dt.hour,
				minutes => $dt.minute,
				seconds => $dt.second
				]
			)
}
