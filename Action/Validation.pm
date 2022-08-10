package Commons::Vote::Action::Validation;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Commons::Link;

our $VERSION = 0.01;

sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	$self->{'schema'} = undef;

	# Process parameters.
	set_params($self, @params);

	$self->{'_commons_link'} = Commons::Link->new(
		'utf-8' => 0,
	);

	return $self;
}

sub check_author {
	my ($self, $number_of_photos) = @_;

	my $authors_hr = {};
	foreach my $value ($self->{'schema'}->resultset('Image')->search) {
		$authors_hr->{$value->uploader->wm_username}++;
	}

	foreach my $author (sort keys %{$authors_hr}) {
		if ($authors_hr->{$author} > $number_of_photos) {
			print "Author '$author': $authors_hr->{$author}\n";
			my $person = $self->{'schema'}->resultset('Person')->search({
				'wm_username' => $author,
			})->single;
			my @images = $self->{'schema'}->resultset('Image')->search({
				'uploader_id' => $person->person_id,
			});
			foreach my $image (@images) {
				print "\t".$self->{'_commons_link'}->mw_link($image->image)."\n";
			}
		}
	}

	return;
}

sub check_image_dimension {
	my ($self, $width, $height) = @_;

	my @rs = $self->{'schema'}->resultset('Image')->search({
		-or => [
			'width' => {'<', $width},
			'height' => {'<', $height},
		],
	});

	foreach my $rs (@rs) {
		print $rs->width.'x'.$rs->height.': '.$self->{'_commons_link'}->link($rs->image)."\n";
	}

	return;
}

sub check_image_dimension_short {
	my ($self, $min_dimension) = @_;

	my @rs = $self->{'schema'}->resultset('Image')->search({
		-and => [
			'width' => {'<', $min_dimension},
			'height' => {'<', $min_dimension},
		],
	});

	foreach my $rs (@rs) {
		print $rs->width.'x'.$rs->height.': '.$self->{'_commons_link'}->link($rs->image)."\n";
	}

	return;
}

# Check if each image is in one section only.
sub check_image_in_one_section {
	my $self = shift;

	my $image_hr = {};
	foreach my $image ($self->{'schema'}->resultset('Image')->search) {
		$image_hr->{$image->image}++;
	}

	foreach my $image (keys %{$image_hr}) {
		if ($image_hr->{$image} > 1) {
			print "Image '$image' is in more sections.\n";
		}
	}

	return;
}

sub check_image_uploaded {
	my ($self, $dt_start, $dt_end) = @_;

	my $dtf = $self->{'schema'}->storage->datetime_parser;
	my @rs = $self->{'schema'}->resultset('Image')->search({
		-or => [
			'image_created' => {'<', $dtf->format_datetime($dt_start)},
			'image_created' => {'>', $dtf->format_datetime($dt_end)},
		],
	});

	foreach my $rs (@rs) {
		print $rs->image_created.': '.$self->{'_commons_link'}->link($rs->image)."\n";
	}

	return;
}

1;

__END__

