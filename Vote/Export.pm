package Activity::Commons::Vote::Export;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Commons::Vote::Fetcher;
use Data::Commons::Vote::Image;
use Data::Commons::Vote::Person;
use Data::Commons::Vote::SectionImage;
use DateTime;
use Error::Pure qw(err);

our $VERSION = 0.01;

sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	# Backend.
	$self->{'backend'} = undef;

	# Process parameters.
	set_params($self, @params);

	# DB backend.
	if (! defined $self->{'backend'}) {
		err "Parameter 'backend' is required.";
	}

	return $self;
}

sub xls {
	my $self = shift;
}

1;

__END__

