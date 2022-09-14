package Activity::Commons::Vote::Stats;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Commons::Link;
use Commons::Vote::Backend;
use DateTime;
use DateTime::Format::Strptime;
use Unicode::UTF8 qw(decode_utf8);

our $VERSION = 0.01;

sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	$self->{'schema'} = undef;

	# Process parameters.
	set_params($self, @params);

	$self->{'_backend'} = Commons::Vote::Backend->new(
		'schema' => $self->{'schema'},
	);

	$self->{'_dt_parser'} = DateTime::Format::Strptime->new(
		pattern => '%FT%T',
		time_zone => 'UTC',
	);

	return $self;
}

sub newcomers {
	my ($self, $competition_id) = @_;

	my $comp = $self->{'_backend'}->fetch_competition($competition_id);
	if (! defined $comp) {
		return ();
	}

	my @newcomers = ();
	my $person_id = {};
	foreach my $image ($self->{'_backend'}->fetch_images) {
		my $uploader = $image->uploader->wm_username;
		if (! exists $person_id->{$uploader}) {
			$person_id->{$uploader} = 1;
			if ($self->_is_newcomer($image->uploader, $comp)) {
				push @newcomers, $image->uploader;
			}
		}
	}

	return @newcomers;
}

sub _is_newcomer {
	my ($self, $person, $comp) = @_;

	# Not upload.
	if (! defined $person->first_upload_at) {
		return 0;
	}

	# Timestamp in <$dt_start, $dt_end>.
	if (DateTime->compare($comp->dt_from, $person->first_upload_at) == -1
		&& DateTime->compare($person->first_upload_at, $comp->dt_to) < 1) {

		return 1;
	} else {
		return 0;
	}
}

1;

__END__

