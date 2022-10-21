package Activity::Commons::Vote::Load;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Commons::Vote::Fetcher;
use Data::Commons::Vote::Image;
use Data::Commons::Vote::License;
use Data::Commons::Vote::Person;
use Data::Commons::Vote::SectionImage;
use DateTime;
use DateTime::Format::ISO8601;
use English;
use Error::Pure qw(err);
use HTML::Strip;
use Scalar::Util qw(blessed);
use Unicode::UTF8 qw(encode_utf8);
use Wikibase::API;

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

	# Wikibase API object.
	$self->{'_wikibase_api'} = Wikibase::API->new(
		'mediawiki_site' => 'www.wikidata.org',
	);

	# HTML strip object.
	$self->{'_html_strip'} = HTML::Strip->new;

	# Log message.
	$self->{'log'} = [];

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

	# Log type.
	my $log_type = $self->{'backend'}->fetch_log_type_name('load_competition');

	# Competition.
	my $competition = $self->{'backend'}->fetch_competition($competition_id);

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

sub load_commons_image {
	my ($self, $commons_name) = @_;

	# First upload revision.
	my $image_first_rev_hr = $self->{'_fetcher'}->image_upload_revision($commons_name);
	$self->_verbose("Fetch first revision for image '$commons_name'.");

	# Extra info.
	my $image_info_hr = $self->{'_fetcher'}->image_info($commons_name);
	$self->_verbose("Fetch image info for image '$commons_name'.");

	# Structured data.
	my $struct_data = $self->{'_fetcher'}->image_structured_data('M'.$image_info_hr->{'pageid'});
	$self->_verbose("Fetch image structured data for image '$commons_name'.");

	# Fetch license.
	my $license_qid = $self->_look_for_structured_item($struct_data, 'P275');
	my $license;
	if (defined $license_qid) {
		$license = $self->_license_text($license_qid);
		$self->_verbose("Found license in structured data for image '$commons_name' (".$license->text.').');
	}

	# Fetch inception.
	my $inception = $self->_look_for_structured_item($struct_data, 'P571');
	my $dt_created;
	if (defined $inception) {

		# Strip + on begin.
		if ($inception =~ m/^\+(.*)$/ms) {
			$inception = $1;
		}
		$dt_created = eval {
			DateTime::Format::ISO8601->parse_datetime($inception);
		};
		if ($EVAL_ERROR) {
			$self->_verbose($EVAL_ERROR.': '.$commons_name);
		} else {
			$self->_verbose("Found inception in structured data for image '$commons_name' (".$dt_created.').');
		}
	}

	# Fetch creator.
	my $author;
	my $creator = $self->_look_for_structured_item($struct_data, 'P170');
	if (defined $creator) {
		$author = $self->_human_name($creator);
		$self->_verbose("Found creator in structured data for image '$commons_name' (".$author.').');
	}

	# Fetch or create uploader.
	my $uploader;
	if (exists $image_first_rev_hr->{'user'}) {
		$uploader = $self->_uploader_wm_username($image_first_rev_hr->{'user'});
		$self->_verbose("Fetch or create uploader record for ".
			"Wikimedia user '$image_first_rev_hr->{'user'}'.");
	}

	if (! defined $dt_created && defined $image_info_hr->{'datetime_created'}) {
		# YYYY-MM-DD HH:MM:SS
		$dt_created = eval {
			$self->_commons_ts2_to_dt($image_info_hr->{'datetime_created'}, $commons_name);
		};
		if ($EVAL_ERROR) {
			$self->_verbose($EVAL_ERROR.': '.$commons_name);
		} else {
			$self->_verbose("Parse created date from 'datetime_created' field.");
		}
	}

	# Fix comment.
	my $comment = $self->{'_html_strip'}->parse(substr($image_info_hr->{'comment'}, 0, 1000));
	$self->{'_html_strip'}->eof;

	my $image = $self->{'backend'}->save_image(
		Data::Commons::Vote::Image->new(
			defined $author ? ('author' => $author) : (),
			'comment' => $comment,
			'commons_name' => $commons_name,
			'created_by' => $self->{'creator'},
			'dt_created' => $dt_created,
			# YYYY-MM-DDTHH:MM:SS
			'dt_uploaded' => $self->_commons_ts_to_dt($image_first_rev_hr->{'timestamp'}),
			'height' => $image_info_hr->{'height'},
			'page_id' => $image_info_hr->{'pageid'},
			'size' => $image_info_hr->{'size'},
			'uploader' => $uploader,
			'width' => $image_info_hr->{'width'},
			defined $license ? ('license_obj' => $license) : (),
		),
	);
	$self->_verbose("Save image '$commons_name'.");

	return $image;
}

sub _commons_ts_to_dt {
	my ($self, $ts, $image) = @_;

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
	my ($self, $ts, $image) = @_;

	my ($date, $time) = split m/\s+/ms, $ts;
	my ($year, $month, $day) = split m/-/ms, $date;
	my ($hour, $min, $sec);
	if (defined $time) {
		($hour, $min, $sec) = split m/:/ms, $time;
	}

	my $dt = eval {
		DateTime->new(
			defined $day ? ('day' => int($day)) : (),
			defined $month ? ('month' => int($month)) : (),
			defined $year ? ('year' => int($year)) : (),
			defined $hour ? ('hour' => int($hour)) : (),
			defined $min ? ('minute' => int($min)) : (),
			defined $sec ? ('second' => int($sec)) : (),
		);
	};
	if ($EVAL_ERROR) {
		err 'Cannot parse date.',
			'Date from Wikimedia Commons', $ts,
			'Image on Wikimedia Commons', encode_utf8($image),
		;
	}

	return $dt;
}

sub _human_name {
	my ($self, $human_qid) = @_;

	my $human_name;
	my $item = $self->{'_wikibase_api'}->get_item($human_qid);
	if ($item) {
		my $label_ar = $item->labels;
		foreach my $label (@{$label_ar}) {
			# XXX language.
			if (defined $label->value) {
				$human_name = $label->value;
				last;
			}
		}
	} else {
		return;
	}

	return $human_name;
}

sub _license_text {
	my ($self, $license_qid) = @_;

	my $license = $self->{'backend'}->fetch_license_by_qid($license_qid);
	if (! defined $license) {

		# Fetch license from Wikidata.
		my $item = $self->{'_wikibase_api'}->get_item($license_qid);
		my ($title, $short_name);
		if ($item) {
			$title = $self->_look_for_structured_item($item, 'P1476');
			$short_name = $self->_look_for_structured_item($item, 'P1813');
		} else {
			return;
		}
		if (! $title) {
			err 'No license text.',
				'Wikidata QID', $license_qid,
			;
		}

		$license = $self->{'backend'}->save_license(
			Data::Commons::Vote::License->new(
				'created_by' => $self->{'creator'},
				'qid' => $license_qid,
				'short_name' => $short_name,
				'text' => $title,
			),
		);
	}

	return $license;
}

sub _load_section {
	my ($self, $section_id, $opts_hr) = @_;

	# Over all categories defined in section.
	$self->_verbose("Fetch section with id '$section_id' categories");
	foreach my $category ($self->{'backend'}->fetch_section_categories($section_id)) {

		# Over all images in category.
		my @images;
		if (defined $opts_hr && exists $opts_hr->{'recursive'}
			&& $opts_hr->{'recursive'} == 1) {

			@images = $self->{'_fetcher'}->images_in_category_recursive($category);
		} else {
			@images = $self->{'_fetcher'}->images_in_category($category);
		}
		$self->_verbose("Fetch images in Wikimedia Commons category '$category'.");
		foreach my $image_hr (@images) {
			my $image = $self->load_commons_image($image_hr->{'title'});

			$self->{'backend'}->save_section_image(
				Data::Commons::Vote::SectionImage->new(
					'created_by' => $self->{'creator'},
					'image' => $image,
					'section_id' => $section_id,
				),
			);
			$self->_verbose("Save image '$image_hr->{'title'}' in section with id '$section_id'.");
		}	
	}

	return;
}

sub _look_for_structured_item {
	my ($self, $item, $property) = @_;

	if (! defined $item) {
		return;
	}

	# XXX What about multiple values.
	# XXX In multiple languages?
	my $item_value;

	foreach my $statement (@{$item->statements}) {
		my $snak = $statement->snak;
		if ($snak->snaktype ne 'value' || $snak->property ne $property) {
			next;
		}
		my $datavalue = $snak->datavalue;
		my $value = $datavalue->value;
		if (defined $value) {
			$item_value = $value;
			last;
		}
	}

	return $item_value;
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
					'wm_username' => $wm_username,
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

	push @{$self->{'log'}}, $message;

	return;
}

1;

__END__

