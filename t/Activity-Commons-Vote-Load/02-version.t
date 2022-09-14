use strict;
use warnings;

use Activity::Commons::Vote::Load;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Activity::Commons::Vote::Load::VERSION, 0.01, 'Version.');
