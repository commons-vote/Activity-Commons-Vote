package Activity::Commons::Vote::Import;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Data::Commons::Vote::Category;
use Data::Commons::Vote::Competition;
use Data::Commons::Vote::PersonRole;
use Data::Commons::Vote::Section;
use Error::Pure qw(err);
use Wikibase::API;
use Wikibase::Datatype::Query;

our $VERSION = 0.01;

sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	# Backend.
	$self->{'backend'} = undef;

	# Creator.
	$self->{'creator'} = undef;

	# Process parameters.
	set_params($self, @params);

	# DB backend.
	if (! defined $self->{'backend'}) {
		err "Parameter 'backend' is required.";
	}

	$self->{'_wikibase_api'} = Wikibase::API->new(
		'mediawiki_site' => 'www.wikidata.org',
	);

	# Wikibase datatype query.
	$self->{'_wikibase_query'} = Wikibase::Datatype::Query->new;

	return $self;
}

sub wd_competition {
	my ($self, $competition_qid) = @_;

	my $item = $self->{'_wikibase_api'}->get_item($competition_qid);

	my $title = $self->{'_wikibase_query'}->query_item($item, 'P1476');
	my $logo = $self->{'_wikibase_query'}->query_item($item, 'P154');
	my $organizer_qid = $self->{'_wikibase_query'}->query_item($item, 'P664');
	my $organizer_item = $self->{'_wikibase_api'}->get_item($organizer_qid);
	my ($organizer, $organizer_logo);
	if ($organizer_item) {
		$organizer = $self->{'_wikibase_query'}->query_item($organizer_item, 'P1448');
		$organizer_logo = $self->{'_wikibase_query'}->query_item($organizer_item, 'P154');
	}
	my $competition = Data::Commons::Vote::Competition->new(
		'created_by' => $self->{'creator'},
		'logo' => $logo,
		'name' => $title,
		'organizer' => $organizer,
		'organizer_logo' => $organizer_logo,
		'wd_qid' => $competition_qid,
	);
	$competition = $self->{'backend'}->save_competition($competition);

	my @has_part_qids = $self->{'_wikibase_query'}->query_item($item, 'P527');
	my @sections;
	foreach my $part_qid (@has_part_qids) {
		my $part_item = $self->{'_wikibase_api'}->get_item($part_qid);
		my $part_title = $self->{'_wikibase_query'}->query($part_item, 'P1476');
		my $part_logo = $self->{'_wikibase_query'}->query($part_item, 'P154');
		my $section = Data::Commons::Vote::Section->new(
			'competition' => $competition,
			'created_by' => $self->{'creator'},
			'logo' => $part_logo,
			'name' => $part_title,
		);
		$section = $self->{'backend'}->save_section($section);

		my @part_commons_cat = $self->{'_wikibase_query'}->query($part_item, 'P373');
		foreach my $part_commons_cat (@part_commons_cat) {
			my $cat = Data::Commons::Vote::Category->new(
				'category' => $part_commons_cat,
				'created_by' => $self->{'creator'},
				'section_id' => $section->id,
			);
			$cat = $self->{'backend'}->save_section_category($cat);
		}
	}

	# Save person role.
	my $competition_admin = $self->{'backend'}->fetch_role({
		'name' => 'competition_admin',
	});
	$self->{'backend'}->save_person_role(Data::Commons::Vote::PersonRole->new(
		'competition' => $competition,
		'created_by' => $self->{'creator'},
		'person' => $self->{'creator'},
		'role' => $competition_admin,
	));

	return $competition->id;
}

1;

__END__

