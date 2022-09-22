use strict;
use warnings;

use Test::NoWarnings;
use Test::Pod::Coverage 'tests' => 2;

# Test.
pod_coverage_ok('Activity::Commons::Vote::Delete', 'Activity::Commons::Vote::Delete is covered.');
