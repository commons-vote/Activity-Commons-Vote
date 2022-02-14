use strict;
use warnings;

use Commons::Vote::Action::Load;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Commons::Vote::Action::Load::VERSION, 0.01, 'Version.');
