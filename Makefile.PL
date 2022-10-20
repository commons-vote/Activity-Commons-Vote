use lib '.';
use strict;
use warnings;

use inc::Module::Install;

# Definition.
abstract 'Activities for commons.vote application.';
author 'Michal Josef Spacek <skim@cpan.org>';
author_requires 'English' => 0;
author_requires 'File::Object' => 0.03;
author_requires 'Test::More' => 0;
author_requires 'Test::NoWarnings' => 0;
author_requires 'Test::Pod' => 0;
author_requires 'Test::Pod::Coverage' => 0;
license 'bsd';
name 'Activity-Commons-Vote';
readme_from 'Vote.pm';
recursive_author_tests('xt');
requires 'Backend::DB::Commons::Vote' => 0;
requires 'Class::Utils' => 0;
requires 'Commons::Link' => 0;
requires 'Commons::Vote::Fetcher' => 0;
requires 'Data::Commons::Vote::Image' => 0;
requires 'Data::Commons::Vote::License' => 0;
requires 'Data::Commons::Vote::Person' => 0;
requires 'Data::Commons::Vote::SectionImage' => 0;
requires 'DateTime' => 0;
requires 'DateTime::Format::Strptime' => 0;
requires 'DateTime::Format::ISO8601' => 0;
requires 'English' => 0;
requires 'Error::Pure' => 0;
requires 'Scalar::Util' => 0;
requires 'Unicode::UTF8' => 0;
requires 'Wikibase::API' => 0;
requires 'perl' => '5.8.0';
resources 'bugtracker' => 'https://github.com/commons-vote/Activity-Commons-Vote/issues';
resources 'homepage' => 'https://github.com/commons-vote/Activity-Commons-Vote';
resources 'repository' => 'git://github.com/commons-vote/Activity-Commons-Vote';
test_requires 'English' => 0;
test_requires 'Error::Pure::Utils' => 0.22;
test_requires 'File::Object' => 0.03;
test_requires 'Test::More' => 0;
test_requires 'Test::NoWarnings' => 0;
tests_recursive;
version '0.01';

# Run.
WriteAll();
