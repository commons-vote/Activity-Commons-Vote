use strict;
use warnings;

use Test::NoWarnings;
use Test::Pod::Coverage 'tests' => 2;

# Test.
pod_coverage_ok('Commons::Vote::Action::Load', 'Commons::Vote::Action::Load is covered.');
