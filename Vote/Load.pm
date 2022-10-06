package Activity::Commons::Vote::Load;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Commons::Vote::Fetcher;
use Data::Commons::Vote::Image;
use Data::Commons::Vote::Person;
use Data::Commons::Vote::SectionImage;
use DateTime;
use Error::Pure qw(err);
use Scalar::Util qw(blessed);
use Unicode::UTF8 qw(encode_utf8);

our $VERSION = 0.01;

sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	# Backend.
	$self->{'backend'} = undef;

	# Creator.
	$self->{'creator'} = undef;

	# Cache of uploaders.
	$self->{'uploaders'} = {};

	# Verbose print callback.
	$self->{'verbose_cb'} = undef;

	# Process parameters.
	set_params($self, @params);

	if (! defined $self->{'creator'}) {
		err "Parameter 'creator' is required.";
	}

	# DB backend.
	if (! defined $self->{'backend'}) {
		err "Parameter 'backend' is required.";
	}
	if (! blessed($self->{'backend'}) || ! $self->{'backend'}->isa('Backend::DB::Commons::Vote')) {
		err "Parameter 'backend' must be a 'Backend::DB::Commons::Vote' object.";
	}

	# Wikimedia Commons fetcher.
	$self->{'_fetcher'} = Commons::Vote::Fetcher->new;

	# Check verbose code.
	if (defined $self->{'verbose_cb'} && ref $self->{'verbose_cb'} ne 'CODE') {
		err "Parameter 'verbose_cb' must be a code.";
	}

	return $self;
}

sub load {
	my ($self, $competition_id, $opts_hr) = @_;

	my @sections = $self->{'backend'}->fetch_competition_sections($competition_id);
	foreach my $section (@sections) {
		$self->_load_section($section->id, $opts_hr);
	}

	# Update loaded timestamp in competition table.
	my $dt_now = DateTime->now;
	$self->{'backend'}->schema->resultset('Competition')->search({
		'competition_id' => $competition_id
	})->update({'images_loaded_at' => $dt_now});

	return;
}


sub _commons_ts_to_dt {
	my ($self, $ts) = @_;

	my ($date, $time) = split m/T/ms, $ts;
	my ($year, $month, $day) = split m/-/ms, $date;
	my ($hour, $min, $sec) = split m/:/ms, $time;

	return DateTime->new(
		'day' => $day,
		'month' => $month,
		'year' => $year,
		'hour' => $hour,
		'minute' => $min,
		'second' => $sec,
	);
}

sub _commons_ts2_to_dt {
	my ($self, $ts) = @_;

	my ($date, $time) = split m/\s+/ms, $ts;
	my ($year, $month, $day) = split m/-/ms, $date;
	my ($hour, $min, $sec);
	if (defined $time) {
		($hour, $min, $sec) = split m/:/ms, $time;
	}

	return DateTime->new(
		'day' => int($day),
		'month' => int($month),
		'year' => int($year),
		defined $hour ? ('hour' => int($hour)) : (),
		defined $min ? ('minute' => int($min)) : (),
		defined $sec ? ('second' => int($sec)) : (),
	);
}

sub _load_section {
	my ($self, $section_id, $opts_hr) = @_;

	# Over all categories defined in section.
	$self->_verbose("Fetch section with id '$section_id' categories");
	foreach my $category ($self->{'backend'}->fetch_section_categories($section_id)) {

		# Over all images in category.
		$self->_verbose("Fetch images in Wikimedia Commons category '$category'.");
		my @images;
		if (defined $opts_hr && exists $opts_hr->{'recursive'}
			&& $opts_hr->{'recursive'} == 1) {

			@images = $self->{'_fetcher'}->images_in_category_recursive($category);
		} else {
			@images = $self->{'_fetcher'}->images_in_category($category);
		}
		foreach my $image_hr (@images) {

			# First upload revision.
			$self->_verbose("Fetch first revision for image '$image_hr->{'title'}'.");
			my $image_first_rev_hr = $self->{'_fetcher'}
				->image_upload_revision($image_hr->{'title'});

			# Extra info.
			$self->_verbose("Fetch image info for image '$image_hr->{'title'}'.");
			my $image_info_hr = $self->{'_fetcher'}
				->image_info($image_hr->{'title'});

			# Fetch or create uploader.
			$self->_verbose("Fetch or create uploader record for ".
				"Wikimedia user '$image_first_rev_hr->{'user'}'.");
			my $uploader = $self->_uploader_wm_username(
				$image_first_rev_hr->{'user'});

			# TODO Find or create, jinak duplikuji
			$self->_verbose("Save image '$image_hr->{'title'}'.");
			# TODO Store comment
			my $image = $self->{'backend'}->save_image(
				Data::Commons::Vote::Image->new(
					'commons_name' => $image_hr->{'title'},
					'created_by' => $self->{'creator'},
					# YYYY-MM-DD HH:MM:SS
					'dt_created' => $self->_commons_ts2_to_dt($image_info_hr->{'datetime_created'}),
					# YYYY-MM-DDTHH:MM:SS
					'dt_uploaded' => $self->_commons_ts_to_dt($image_first_rev_hr->{'timestamp'}),
					'height' => $image_info_hr->{'height'},
					'size' => $image_info_hr->{'size'},
					'uploader' => $uploader,
					'width' => $image_info_hr->{'width'},
				),
			);

			$self->_verbose("Save image '$image_hr->{'title'}' in section with id '$section_id'.");
			$self->{'backend'}->save_section_image(
				Data::Commons::Vote::SectionImage->new(
					'created_by' => $self->{'creator'},
					'image' => $image,
					'section_id' => $section_id,
				),
			);
		}	
	}

	return;
}

sub _uploader_wm_username {
	my ($self, $wm_username) = @_;

	if (! exists $self->{'uploaders'}->{'wm_username'}->{$wm_username}) {
		my @people = $self->{'backend'}->fetch_people({'wm_username' => $wm_username});
		if (@people > 1) {
			err "Bad identifier 'wm_username'. Has multiple values.";
		}
		my $uploader = $people[0];
		if (! $uploader) {

			# Timestamp of first upload.
			my $dt_first_upload
				= $self->{'_fetcher'}->date_of_first_upload($wm_username);

			# TODO Store author name (from $image_info_hr)
			$uploader = $self->{'backend'}->save_person(
				Data::Commons::Vote::Person->new(
					'first_upload_at' => $dt_first_upload,
					'wm_username' => encode_utf8($wm_username),
				),
			);
		}
		$self->{'uploaders'}->{'wm_username'}->{$wm_username} = $uploader;
	}

	return $self->{'uploaders'}->{'wm_username'}->{$wm_username};
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

