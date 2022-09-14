use strict;
use warnings;

use Activity::Commons::Vote::Export;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Activity::Commons::Vote::Export::VERSION, 0.01, 'Version.');
