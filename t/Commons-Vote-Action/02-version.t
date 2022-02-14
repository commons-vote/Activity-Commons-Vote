use strict;
use warnings;

use Commons::Vote::Action;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Commons::Vote::Action::VERSION, 0.01, 'Version.');
