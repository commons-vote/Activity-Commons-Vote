use strict;
use warnings;

use Activity::Commons::Vote::Delete;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Activity::Commons::Vote::Delete::VERSION, 0.01, 'Version.');
