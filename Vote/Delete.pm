package Activity::Commons::Vote::Delete;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Error::Pure qw(err);
use Scalar::Util qw(blessed);

our $VERSION = 0.01;

sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	# Backend.
	$self->{'backend'} = undef;

	# Verbose print callback.
	$self->{'verbose_cb'} = undef;

	# Process parameters.
	set_params($self, @params);

	# DB backend.
	if (! defined $self->{'backend'}) {
		err "Parameter 'backend' is required.";
	}
	if (! blessed($self->{'backend'}) || ! $self->{'backend'}->isa('Backend::DB::Commons::Vote')) {
		err "Parameter 'backend' must be a 'Backend::DB::Commons::Vote' object.";
	}

	# Check verbose code.
	if (defined $self->{'verbose_cb'} && ref $self->{'verbose_cb'} ne 'CODE') {
		err "Parameter 'verbose_cb' must be a code.";
	}

	return $self;
}

sub delete {
	my ($self, $competition) = @_;

	if (! blessed($competition) || ! $competition->isa('Data::Commons::Vote::Competition')) {
		err "Bad object, must be a 'Data::Commons::Vote::Competition' object.";
	}

	$self->{'backend'}->delete_competition($competition->id);
	$self->_verbose("Delete competition with '".$competition->id."' id.");

	return;
}

sub _verbose {
	my ($self, $message) = @_;

	if (defined $self->{'verbose_cb'}) {
		$self->{'verbose_cb'}->($message);
	}

	return;
}

1;

__END__

