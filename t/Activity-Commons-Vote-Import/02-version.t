use strict;
use warnings;

use Activity::Commons::Vote::Import;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Activity::Commons::Vote::Import::VERSION, 0.01, 'Version.');
