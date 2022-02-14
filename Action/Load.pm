package Commons::Vote::Action::Load;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Commons::Vote::Fetcher;
use DateTime;
use Error::Pure qw(err);
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

	# Wikimedia Commons fetcher.
	$self->{'_fetcher'} = Commons::Vote::Fetcher->new;

	# Check verbose code.
	if (defined $self->{'verbose_cb'} && ref $self->{'verbose_cb'} ne 'CODE') {
		err "Parameter 'verbose_cb' must be a code.";
	}

	return $self;
}

sub load {
	my ($self, $section_id) = @_;

	# Over all categories defined in section.
	$self->_verbose("Fetch section with id '$section_id' categories");
	foreach my $category ($self->{'backend'}->fetch_section_categories($section_id)) {

		# Over all images in category.
		$self->_verbose("Fetch images in Wikimedia Commons category '$category'.");
		foreach my $image_hr ($self->{'_fetcher'}->images_in_category($category)) {

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
			my $image = $self->{'backend'}->save_image({
				'image' => encode_utf8($image_hr->{'title'}),
				'uploader_id' => $uploader->id,
				'image_created' => $image_first_rev_hr->{'timestamp'},
				'created_by' => $self->{'creator'}->id,
				'width' => $image_info_hr->{'width'},
				'height' => $image_info_hr->{'height'},
			});

			$self->_verbose("Save image '$image_hr->{'title'}' in section with id '$section_id'.");
			$self->{'backend'}->save_section_image({
				'section_id' => $section_id,
				'image_id' => $image->id,
			});
		}	
	}

	return;
}

sub _uploader_wm_username {
	my ($self, $wm_username) = @_;

	if (! exists $self->{'uploaders'}->{'wm_username'}->{$wm_username}) {
		my @users = $self->{'backend'}->fetch_users({'wm_username' => $wm_username});
		if (@users > 1) {
			err "Bad identifier 'wm_username'. Has multiple values.";
		}
		my $uploader = $users[0];
		if (! $uploader) {

			# Timestamp of first upload.
			my $dt_first_upload
				= $self->{'_fetcher'}->date_of_first_upload($wm_username);

			# TODO Store author name (from $image_info_hr)
			$uploader = $self->{'backend'}->save_user({
				'first_upload_at' => $dt_first_upload,
				'wm_username' => encode_utf8($wm_username),
			});
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

