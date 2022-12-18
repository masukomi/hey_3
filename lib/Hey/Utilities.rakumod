unit module Hey::Utilities;
use Time::Duration;

our sub midnightify(DateTime $dt) returns DateTime is export {
	$dt.earlier(
				[
				hours => $dt.hour,
				minutes => $dt.minute,
				seconds => $dt.second
				]
			)
}

our sub duration-string(Int $started_at, $ended_at) returns Str is export {
	return "ongoing" unless $ended_at ~~ Int;
	my $seconds = $ended_at - $started_at;
	return concise(duration($seconds));
}
