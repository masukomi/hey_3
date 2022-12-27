unit module Hey::Exceptions;

class Hey::Exceptions::Exitable is Exception {
	has Int $.exit_code;
	has Str $.message;
}
