package Activity::Commons::Vote::Import;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Commons::Vote::Fetcher;
use Data::Commons::Vote::Image;
use Data::Commons::Vote::Person;
use Data::Commons::Vote::SectionImage;
use DateTime;
use Error::Pure qw(err);
use Wikibase::API;

use Wikibase::Datatype::Print::Item;

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

	$self->{'_wikibase_api'} = Wikibase::API->new(
		'mediawiki_site' => 'www.wikidata.org',
	);

	return $self;
}

sub wd_competition {
	my ($self, $competition_qid) = @_;

	my $item = $self->{'_wikibase_api'}->get_item($competition_qid);
	# TODO remove
	print scalar Wikibase::Datatype::Print::Item::print($item);
	print "\n";

	# TODO

	return;
}

1;

__END__

