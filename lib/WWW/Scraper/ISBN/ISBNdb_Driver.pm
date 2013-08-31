package WWW::Scraper::ISBN::ISBNdb_Driver;

use strict;
use warnings;

our $VERSION = '0.07';

#--------------------------------------------------------------------------

###########################################################################
# Inheritence

use base qw(WWW::Scraper::ISBN::Driver);

###########################################################################
# Modules

use LWP::UserAgent;
use XML::LibXML;
use Carp;

###########################################################################
# Variables

our $ACCESS_KEY = undef;
our $user_agent = new LWP::UserAgent();

my $API_VERSION = 'v1';
my $LB2G  = 0.00220462;     # number of pounds (lbs) in a gram

my %editions = (
    '(pbk.)'            => 'Paperback',
    '(electronic bk.)'  => 'eBook'
);

# in preparation for moving to API v2
my %api_paths = (
    'v1'    => { format => 'http://isbndb.com/api/%s.xml?access_key=%s&index1=%s&results=%s&value1=%s', fields => [ qw( search_type access_key search_field results_type search_param ) ] },
);

#--------------------------------------------------------------------------

=head1 NAME

WWW::Scraper::ISBN::ISBNdb_Driver - Search driver for the isbndb.com online book catalog

=head1 SYNOPSIS

  use WWW::Scraper::ISBN;
  my $scraper = new WWW::Scraper::ISBN();
  $scraper->drivers( qw/ ISBNdb / );
  $WWW::Scraper::ISBN::ISBNdb_Driver::ACCESS_KEY = 'xxxx'; # Your isbndb.com access key

  my $isbn = '0596101058';
  my $result = $scraper->search( $isbn );

  if( $result->found ) {
    my $book = $result->book;
    print "ISBN: ",      $book->{isbn},      "\n";
    print "Title: ",     $book->{title},     "\n";
    print "Author: ",    $book->{author},    "\n";
    print "Publisher: ", $book->{publisher}, "\n";
    print "Year: ",      $book->{year},      "\n";
  }

=head1 DESCRIPTION

This is a WWW::Scraper::ISBN driver that pulls data from
L<http://www.isbndb.com>. Consult L<WWW::Scraper::ISBN> for usage
details.

=cut

#--------------------------------------------------------------------------

###########################################################################
# Public Interface

sub search {
    my( $self, $isbn ) = @_;
    $self->found(0);
    $self->book(undef);

    my( $details, $details_url ) = $self->_fetch( 'books', 'isbn' => $isbn, 'details' );
    my( $authors, $authors_url ) = $self->_fetch( 'books', 'isbn' => $isbn, 'authors' );

    return  unless $details && $self->_contains_book_data($details);

    my %book = (
        book_link   => $details_url,

        # deprecated
        _source_url => $details_url
    );

    $self->_get_pubdata(\%book,$details);
    $self->_get_details(\%book,$details);
    $self->_get_authors(\%book,$authors);

    $self->book(\%book);
    $self->found(1);
    return $self->book;
}

###########################################################################
# Private Interface

sub _contains_book_data {
    my( $self, $doc ) = @_;
    return $doc->getElementsByTagName('BookData')->size > 0;
}

#<ISBNdb server_time="2013-08-31T08:52:38Z">
#<BookList total_results="1" page_size="10" page_number="1" shown_results="1">
#<BookData book_id="learning_perl_a03" isbn="0596101058" isbn13="9780596101053">
#<Title>Learning Perl</Title>
#<TitleLong></TitleLong>
#<AuthorsText>Randal L. Schwartz, Tom Phoenix and brian d foy</AuthorsText>
#<PublisherText publisher_id="oreilly">Sebastopol, CA : O\'Reilly, c2005.</PublisherText>
#<Authors>
#<Person person_id="schwartz_randal_l">Schwartz, Randal L.</Person>
#<Person person_id="tom_phoenix">Tom Phoenix</Person>
#<Person person_id="brian_d_foy">brian d foy</Person>
#</Authors>
#</BookData>
#</BookList>
#</ISBNdb>

sub _get_authors {
    my( $self, $book, $authors ) = @_;
    my $people = $authors->findnodes('//Authors/Person');
    my @people;
    for( my $i = 0; $i < $people->size; $i++ ) {
        my $person = $people->get_node($i);
        push @people, $person->to_literal;
    }

    my $str = join '; ', @people;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;

    $book->{author} = $str;
}

sub _get_pubdata {
    my( $self, $book, $doc ) = @_;

    my $pubtext = $doc->findnodes('//PublisherText')->to_literal;
    my $details = $doc->findnodes('//Details/@edition_info')->to_literal;

    my $year = '';
    if( $pubtext =~ /(\d{4})/ ) { $year = $1 }
    elsif( $details =~ /(\d{4})/ ) { $year = $1 }

    my $pub_id = ($doc->findnodes('//PublisherText/@publisher_id'))[0]->to_literal;

    my $publisher = $self->_fetch( 'publishers', 'publisher_id', $pub_id, 'details' );
    my $data = ($publisher->findnodes('//PublisherData'))[0];

    $book->{publisher} = ($data->findnodes('//Name'))[0]->to_literal;
    $book->{pubdate}   = $year || '';

    # deprecated
    $book->{location}  = ($data->findnodes('//Details/@location'))[0]->to_literal;
    $book->{year}      = $year || '';
}

#<ISBNdb server_time="2013-08-31T08:52:38Z">
#<BookList total_results="1" page_size="10" page_number="1" shown_results="1">
#<BookData book_id="learning_perl_a03" isbn="0596101058" isbn13="9780596101053">
#<Title>Learning Perl</Title>
#<TitleLong></TitleLong>
#<AuthorsText>Randal L. Schwartz, Tom Phoenix and brian d foy</AuthorsText>
#<PublisherText publisher_id="oreilly">Sebastopol, CA : O\'Reilly, c2005.</PublisherText>
#<Details change_time="2009-04-23T07:13:51Z" price_time="2013-01-01T19:03:44Z" edition_info="(pbk.)" language="eng" physical_description_text="283 p. : ill. ; 24 cm." lcc_number="" dewey_decimal_normalized="5.133" dewey_decimal="005.133" />
#</BookData>
#</BookList>
#</ISBNdb>

sub _get_details {
    my( $self, $book, $doc ) = @_;

    my $isbn10 = $doc->findnodes('//BookData/@isbn')->to_literal;
    my $isbn13 = $doc->findnodes('//BookData/@isbn13')->to_literal;

    $book->{isbn}   = $isbn13;
    $book->{ean13}  = $isbn13;
    $book->{isbn13} = $isbn13;
    $book->{isbn10} = $isbn10;

    my $long_title  = eval { ($doc->findnodes('//TitleLong'))[0]->to_literal };
    my $short_title = eval { ($doc->findnodes('//Title'))[0]->to_literal };
    $book->{title} = $long_title || $short_title;

    my $edition = $doc->findnodes('//Details/@edition_info')->to_literal;
    my $desc    = $doc->findnodes('//Details/@physical_description_text')->to_literal;
    my $dewey   = $doc->findnodes('//Details/@dewey_decimal')->to_literal;

    my ($binding,$date) = $edition =~ /([^;]+);(.*)/;
    my (@size)          = $desc =~ /([\d\.]+)"x([\d\.]+)"x([\d\.]+)"/;
    my ($weight)        = $desc =~ /([\d\.]+) lbs?/;
    my ($pages)         = $desc =~ /(\d) pages/;
    ($pages)            = $desc =~ /(\d+) p\./ unless($pages);

    my ($height,$width,$depth) = sort {$b <=> $a} @size;

    $book->{height}  = $height * 10     if($height);
    $book->{width}   = $width  * 10     if($width);
    $book->{depth}   = $depth  * 10     if($depth);
    $book->{weight}  = $weight * $LB2G  if($weight);
    $book->{pubdate} = $date    if($date);
    $book->{binding} = $editions{$edition} || $binding || $edition;
    $book->{pages}   = $pages;
    $book->{dewey}   = "$dewey";
}


sub _fetch {
    my( $self, @args ) = @_;
    my $parser = new XML::LibXML();
    my $url = $self->_url( @args );
    my $xml = $self->_fetch_data($url);
    return  unless($xml && $xml !~ /^<!DOCTYPE html>/);

    my $doc = $parser->parse_string( $xml );
    return wantarray ? ( $doc, $url ) : $doc;
}

sub _fetch_data {
    my( $self, $url ) = @_;
    my $res = $user_agent->get($url);
    return unless $res->is_success;
#    use Data::Dumper;
#    print STDERR "# data=" . Dumper($res);
    return $res->content;
}

sub _url {
    my $self = shift;

    my $access_key = $self->_get_key();
    croak "no access key provided" unless $access_key;

    my %hash = ( access_key => $access_key );
    ($hash{search_type}, $hash{search_field}, $hash{search_param}, $hash{results_type}) = @_;

    my @values = map { $hash{$_} } @{ $api_paths{$API_VERSION}{fields} };
    my $url = sprintf $api_paths{$API_VERSION}{format}, @values;

#    print STDERR "# url=$url\n";
    return $url;
}

sub _get_key {
    return $ACCESS_KEY  if($ACCESS_KEY);

    if($ENV{ISBNDB_ACCESS_KEY}) {
        $ACCESS_KEY = $ENV{ISBNDB_ACCESS_KEY};
        return $ACCESS_KEY;
    }

    for my $dir ( ".", $ENV{HOME}, '~' ) {
        my $file = join( '/', $dir, ".isbndb" );
        next unless -e $file;

        my $fh = IO::File->new($file,'r') or next;
        my $key;
        $key .= $_  while(<$fh>);
        $key =~ s/\s+//gs;
        $fh->close;

        $ACCESS_KEY = $key;
        return $ACCESS_KEY;
    }
}

1;

__END__

=head1 METHODS

=over 4

=item C<search()>

Given an ISBN, will attempt to find the details via the ISBNdb.com API. If a 
valid result is returned, the following fields are returned via the book hash:

  isbn          (now returns isbn13)
  isbn10        
  isbn13
  ean13         (industry name)
  title
  author
  book_link
  publisher
  pubdate
  binding       (if known)
  pages         (if known)
  weight        (if known) (in grammes)
  width         (if known) (in millimetres)
  height        (if known) (in millimetres)
  depth         (if known) (in millimetres)

Deprecated fields, which will be removed in a future version:

  location
  year          # now pubdate
  _source_url   # now book_link

=cut

=back

=head1 THE ACCESS KEY

To use this driver you will need to obtain an access key from isbndb.com. It is
free to sign-up to isbndb.com, and once registered, you can request an API key.

To set the access key in the driver, within your application you will need to 
set the following, after the driver has been loaded, and before you perform a
search.

  $WWW::Scraper::ISBN::ISBNdb_Driver::ACCESS_KEY = 'xxxx';

You can also set the key in the ISBNDB_ACCESS_KEY environment variable.

Alternatively, you can create a '.isbndb' configuration file in your home
directory, which should only contain the key itself.

Reference material for developers can be found at L<http://isbndb.com/api/v2/docs>.

=head1 SEE ALSO

L<WWW::Scraper::ISBN>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-www-scraper-isbn-isbndb_driver at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Scraper-ISBN-ISBNdb_Driver>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Scraper::ISBN::ISBNdb_Driver

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Scraper-ISBN-ISBNdb_Driver>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Scraper-ISBN-ISBNdb_Driver>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Scraper-ISBN-ISBNdb_Driver>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Scraper-ISBN-ISBNdb_Driver>

=back

=head1 AUTHOR

  2006-2013 David J. Iberri, C<< <diberri at cpan.org> >>
  2013      Barbie, E<lt>barbie@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

  Copyright 2004-2013 by David J. Iberri
  Copyright 2013 by Barbie

  This distribution is free software; you can redistribute it and/or
  modify it under the Artistic Licence v2.

=cut
