use strict;
use warnings;

use Activity::Commons::Vote::Validation;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Activity::Commons::Vote::Validation::VERSION, 0.01, 'Version.');
