use strict;
use warnings;

use Commons::Vote::Action::Stats;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Commons::Vote::Action::Stats::VERSION, 0.01, 'Version.');
