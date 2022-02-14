use strict;
use warnings;

use Commons::Vote::Action::Validation;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Commons::Vote::Action::Validation::VERSION, 0.01, 'Version.');
