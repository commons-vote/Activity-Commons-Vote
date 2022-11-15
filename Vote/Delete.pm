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

	# Creator.
	$self->{'creator'} = undef;

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

	# Check creator.
	if (! defined $self->{'creator'}) {
		err "Parameter 'creator' is required.";
	}

	# Check verbose code.
	if (defined $self->{'verbose_cb'} && ref $self->{'verbose_cb'} ne 'CODE') {
		err "Parameter 'verbose_cb' must be a code.";
	}

	# Log message.
	$self->{'log'} = [];

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

sub delete_competition_section_images {
	my ($self, $competition) = @_;

	if (! blessed($competition) || ! $competition->isa('Data::Commons::Vote::Competition')) {
		err "Bad object, must be a 'Data::Commons::Vote::Competition' object.";
	}

	my @sections = $self->{'backend'}->fetch_competition_sections({
		'competition_id' => $competition->id,
	});
	my $num = 0;
	foreach my $section (@sections) {
		my $deleted_images_count = $self->{'backend'}->delete_section_images($section->id);
		if ($deleted_images_count) {
			$self->_verbose("Delete section images with '".$section->id."' id.");
		} else {
			$self->_verbose("No section images for '".$section->id."' id.");
		}
		$num += $deleted_images_count;
	}
	if ($num) {
		$self->_verbose("Delete competion images with '".$competition->id."' id.");
	} else {
		$self->_verbose("No competition images for '".$competition->id."' id.");
	}

	# Log type.
	my $log_type = $self->{'backend'}->fetch_log_type_name('delete_competition_images');

	# Save log.
	$self->{'backend'}->save_log(
		Data::Commons::Vote::Log->new(
			'competition' => $competition,
			'created_by' => $self->{'creator'},
			'log' => (join "\n", @{$self->{'log'}}),
			'log_type' => $log_type,
		),
	);

	# Cleanup log.
	$self->{'log'} = [];

	return;
}

sub _verbose {
	my ($self, $message) = @_;

	if (defined $self->{'verbose_cb'}) {
		$self->{'verbose_cb'}->($message);
	}

	push @{$self->{'log'}}, $message;

	return;
}

1;

__END__

