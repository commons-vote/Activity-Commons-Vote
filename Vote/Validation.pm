package Activity::Commons::Vote::Validation;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Commons::Link;
use Data::Commons::Vote::ValidationBad;
use DateTime;
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

	if (! defined $self->{'creator'}) {
		err "Parameter 'creator' is required.";
	}

	# Check verbose code.
	if (defined $self->{'verbose_cb'} && ref $self->{'verbose_cb'} ne 'CODE') {
		err "Parameter 'verbose_cb' must be a code.";
	}

	$self->{'_commons_link'} = Commons::Link->new(
		'utf-8' => 0,
	);

	$self->{'schema'} = $self->{'backend'}->schema;

	# Log message.
	$self->{'log'} = [];

	return $self;
}

sub check_author_photos {
	my ($self, $competition, $validation) = @_;

	$self->_verbose("Validation '".$validation->validation_type->type."'.");

	my $authors_hr = {};
	foreach my $section (@{$competition->sections}) {
		foreach my $image (@{$section->images}) {
			my $uploader = $image->uploader;
			$authors_hr->{$uploader->wm_username}++;
		}
	}

	$self->_verbose('Options.');
	my $number_of_photos = $validation->options->[0]->value;
	$self->_verbose('  - '.$validation->options->[0]->validation_option->description.': '.$number_of_photos);

	foreach my $author (sort keys %{$authors_hr}) {
		if ($authors_hr->{$author} > $number_of_photos) {
			$self->_verbose("Author '$author': $authors_hr->{$author}");

			# Report photos by author
			# XXX To data object.
			my $person = $self->{'schema'}->resultset('Person')->search({
				'wm_username' => $author,
			})->single;
			# XXX To data object.
			my @images = $self->{'schema'}->resultset('Image')->search({
				'uploader_id' => $person->person_id,
			});
			foreach my $image (@images) {
				$self->{'backend'}->save_validation_bad(Data::Commons::Vote::ValidationBad->new(
					'competition' => $competition,
					'created_by' => $self->{'creator'},
					# XXX To data object.
					'image' => $self->{'backend'}->{'_transform'}->image_db2obj($image),
					'validation_type' => $validation->validation_type,
				));
				$self->_verbose("\t".$self->{'_commons_link'}->mw_link($image->image));
			}
		}
	}

	$self->_validation_log($competition, 'validation_'.$validation->validation_type->type);

	return;
}

sub check_image_dimension {
	my ($self, $competition, $validation) = @_;

	$self->_verbose("Validation '".$validation->validation_type->type."'.");

	$self->_verbose('Options.');
	my ($min_width, $min_height);
	foreach my $option (@{$validation->options}) {
		if ($option->validation_option->option eq 'image_height') {
			$min_height = $option->value;
			$self->_verbose('  - '.$option->validation_option->description.': '.$min_height);
		} elsif ($option->validation_option->option eq 'image_width') {
			$min_width = $option->value;
			$self->_verbose('  - '.$option->validation_option->description.': '.$min_width);
		} else {
			err "Bad validation option for check image dimension.",
				'Option', $option->validation_option->option,
			;
		}
	}

	my $processed_images_hr = {};
	foreach my $section (@{$competition->sections}) {
		foreach my $image (@{$section->images}) {

			# Skip if image is duplicated.
			if (! exists $processed_images_hr->{$image->id}) {
				$processed_images_hr->{$image->id} = 1;
			} else {
				next;
			}

			if ($image->width < $min_width || $image->height < $min_height) {
				$self->{'backend'}->save_validation_bad(Data::Commons::Vote::ValidationBad->new(
					'competition' => $competition,
					'created_by' => $self->{'creator'},
					'image' => $image,
					'validation_type' => $validation->validation_type,
				));
				$self->_verbose($image->width.'x'.$image->height.': '.
					$self->{'_commons_link'}->mw_link($image->commons_name));
			}
		}
	}

	$self->_validation_log($competition, 'validation_'.$validation->validation_type->type);

	return;
}

sub check_image_dimensions_short {
	my ($self, $competition, $validation) = @_;

	$self->_verbose("Validation '".$validation->validation_type->type."'.");

	$self->_verbose('Options.');
	my $min_dimension = $validation->options->[0]->value;
	$self->_verbose('  - '.$validation->options->[0]->validation_option->description.': '.$min_dimension);

	my $processed_images_hr = {};
	foreach my $section (@{$competition->sections}) {
		foreach my $image (@{$section->images}) {

			# Skip if image is duplicated.
			if (! exists $processed_images_hr->{$image->id}) {
				$processed_images_hr->{$image->id} = 1;
			} else {
				next;
			}

			if ($image->width < $min_dimension || $image->height < $min_dimension) {
				$self->{'backend'}->save_validation_bad(Data::Commons::Vote::ValidationBad->new(
					'competition' => $competition,
					'created_by' => $self->{'creator'},
					'image' => $image,
					'validation_type' => $validation->validation_type,
				));
				$self->_verbose($image->width.'x'.$image->height.': '.
					$self->{'_commons_link'}->mw_link($image->commons_name));
			}
		}
	}

	$self->_validation_log($competition, 'validation_'.$validation->validation_type->type);

	return;
}

# Check if each image is in one section only.
sub check_image_in_one_section {
	my ($self, $competition, $validation) = @_;

	$self->_verbose("Validation '".$validation->validation_type->type."'.");

	my $image_hr = {};
	foreach my $section (@{$competition->sections}) {
		foreach my $image (@{$section->images}) {
			if (! exists $image_hr->{$image->commons_name}->{'object'}) {
				$image_hr->{$image->commons_name}->{'object'} = $image;
			}
			$image_hr->{$image->commons_name}->{'count'}++;
		}
	}

	foreach my $image (keys %{$image_hr}) {
		if ($image_hr->{$image}->{'count'} > 1) {
			$self->{'backend'}->save_validation_bad(Data::Commons::Vote::ValidationBad->new(
				'competition' => $competition,
				'created_by' => $self->{'creator'},
				'image' => $image_hr->{$image}->{'object'},
				'validation_type' => $validation->validation_type,
			));
			$self->_verbose("Image '$image' is in more sections.");
		}
	}

	$self->_validation_log($competition, 'validation_'.$validation->validation_type->type);

	return;
}

sub check_image_size {
	my ($self, $competition, $validation) = @_;

	$self->_verbose("Validation '".$validation->validation_type->type."'.");

	$self->_verbose('Options.');
	my $min_size = $validation->options->[0]->value;
	$self->_verbose('  - '.$validation->options->[0]->validation_option->description.': '.$min_size);

	my $processed_images_hr = {};
	foreach my $section (@{$competition->sections}) {
		foreach my $image (@{$section->images}) {

			# Skip if image is duplicated.
			if (! exists $processed_images_hr->{$image->id}) {
				$processed_images_hr->{$image->id} = 1;
			} else {
				next;
			}

			if ($image->size < $min_size) {
				$self->{'backend'}->save_validation_bad(Data::Commons::Vote::ValidationBad->new(
					'competition' => $competition,
					'created_by' => $self->{'creator'},
					'image' => $image,
					'validation_type' => $validation->validation_type,
				));
				$self->_verbose($image->size.': '.
					$self->{'_commons_link'}->mw_link($image->commons_name));
			}
		}
	}

	$self->_validation_log($competition, 'validation_'.$validation->validation_type->type);

	return;
}

sub check_image_created {
	my ($self, $competition, $validation) = @_;

	$self->_verbose("Validation '".$validation->validation_type->type."'.");

	$self->_verbose('Options.');
	my ($dt_start, $dt_end);
	foreach my $option (@{$validation->options}) {
		if ($option->validation_option->option eq 'created_from') {
			$dt_start = $self->_date_option($option->value);;
			$self->_verbose('  - '.$option->validation_option->description.': '.$dt_start);
		} elsif ($option->validation_option->option eq 'created_to') {
			$dt_end = $self->_date_option($option->value);
			$self->_verbose('  - '.$option->validation_option->description.': '.$dt_end);
		} else {
			err "Bad validation option for check date of image creation.",
				'Option', $option->validation_option->option,
			;
		}
	}

	my $processed_images_hr = {};
	foreach my $section (@{$competition->sections}) {
		foreach my $image (@{$section->images}) {

			# Skip if image is duplicated.
			if (! exists $processed_images_hr->{$image->id}) {
				$processed_images_hr->{$image->id} = 1;
			} else {
				next;
			}

			if (DateTime->compare($image->dt_created, $dt_start) == -1
				|| DateTime->compare($dt_end, $image->dt_created) == -1) {

				$self->{'backend'}->save_validation_bad(Data::Commons::Vote::ValidationBad->new(
					'competition' => $competition,
					'created_by' => $self->{'creator'},
					'image' => $image,
					'validation_type' => $validation->validation_type,
				));
				$self->_verbose($image->dt_created.': '.
					$self->{'_commons_link'}->mw_link($image->commons_name));
			}
		}
	}

	$self->_validation_log($competition, 'validation_'.$validation->validation_type->type);

	return;
}

sub check_image_uploaded {
	my ($self, $competition, $validation) = @_;

	$self->_verbose("Validation '".$validation->validation_type->type."'.");

	my ($dt_start, $dt_end);
	foreach my $option (@{$validation->options}) {
		if ($option->validation_option->option eq 'uploaded_from') {
			$dt_start = $self->_date_option($option->value);
			$self->_verbose('  - '.$option->validation_option->description.': '.$dt_start);
		} elsif ($option->validation_option->option eq 'uploaded_to') {
			$dt_end = $self->_date_option($option->value);
			$self->_verbose('  - '.$option->validation_option->description.': '.$dt_end);
		} else {
			err "Bad validation option for check date of image creation.",
				'Option', $option->validation_option->option,
			;
		}
	}

	my $processed_images_hr = {};
	foreach my $section (@{$competition->sections}) {
		foreach my $image (@{$section->images}) {

			# Skip if image is duplicated.
			if (! exists $processed_images_hr->{$image->id}) {
				$processed_images_hr->{$image->id} = 1;
			} else {
				next;
			}

			if (DateTime->compare($image->dt_uploaded, $dt_start) == -1
				|| DateTime->compare($dt_end, $image->dt_uploaded) == -1) {

				$self->{'backend'}->save_validation_bad(Data::Commons::Vote::ValidationBad->new(
					'competition' => $competition,
					'created_by' => $self->{'creator'},
					'image' => $image,
					'validation_type' => $validation->validation_type,
				));
				$self->_verbose($image->dt_uploaded.': '.
					$self->{'_commons_link'}->mw_link($image->commons_name));
			}
		}
	}

	$self->_validation_log($competition, 'validation_'.$validation->validation_type->type);

	return;
}

sub validate {
	my ($self, $competition_id) = @_;

	my $competition = $self->{'backend'}->fetch_competition($competition_id);

	# Delete validations for competition.
	$self->{'backend'}->delete_validation_bads({
		'competition_id' => $competition->id,
	});

	my @validations = @{$competition->validations};
	foreach my $validation (@validations) {
		my $validation_type = $validation->validation_type->type;
		if ($validation_type eq 'check_author_photos') {
			$self->check_author_photos($competition, $validation);
		} elsif ($validation_type eq 'check_image_dimension') {
			$self->check_image_dimension($competition, $validation);
		} elsif ($validation_type eq 'check_image_dimensions_short') {
			$self->check_image_dimensions_short($competition, $validation);
		} elsif ($validation_type eq 'check_image_in_one_section') {
			$self->check_image_in_one_section($competition, $validation);
		} elsif ($validation_type eq 'check_image_size') {
			$self->check_image_size($competition, $validation);
		} elsif ($validation_type eq 'check_image_created') {
			$self->check_image_created($competition, $validation);
		} elsif ($validation_type eq 'check_image_uploaded') {
			$self->check_image_uploaded($competition, $validation);
		} else {
			err "Validation type '$validation_type' doesn't supported.";
		}
	}

	return;
}

sub _date_option {
	my ($self, $option_date) = @_;

	my ($year, $month, $day) = split m/-/ms, $option_date;
	my $dt = DateTime->new(
		'day' => $day,
		'month' => $month,
		'year' => $year,
	);

	return $dt;
}

sub _validation_log {
	my ($self, $competition, $validation_log_type) = @_;

	# Log type.
	my $log_type = $self->{'backend'}->fetch_log_type_name($validation_log_type);

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

