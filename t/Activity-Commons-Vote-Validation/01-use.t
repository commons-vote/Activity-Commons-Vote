use strict;
use warnings;

use Test::More 'tests' => 3;
use Test::NoWarnings;

BEGIN {

	# Test.
	use_ok('Activity::Commons::Vote::Validation');
}

# Test.
require_ok('Activity::Commons::Vote::Validation');
