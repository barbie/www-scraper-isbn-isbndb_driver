package WWW::Scraper::ISBN::ISBNdb_Driver;
use base 'WWW::Scraper::ISBN::Driver';

use strict;
use warnings;

use LWP::UserAgent;
use XML::LibXML;
use Carp;

our $VERSION = '0.07';
our $ACCESS_KEY = undef;

our $user_agent = new LWP::UserAgent();

=head1 NAME

WWW::Scraper::ISBN::ISBNdb_Driver - isbndb.com driver for WWW::Scraper::ISBN

=head1 SYNOPSIS

  use WWW::Scraper::ISBN;
  my $scraper = new WWW::Scraper::ISBN();
  $scraper->drivers( qw/ ISBNdb / );
  $WWW::Scraper::ISBN::ISBNdb_Driver::ACCESS_KEY = 'xxxx'; # Your isbndb.com access key

  my $isbn = '0596101058';
  my $result = $scraper->search( $isbn );

  if( $result->found ) {
    my $book = $result->book;
    print "ISBN: ", $book->{isbn}, "\n";
    print "Title: ", $book->{title}, "\n";
    print "Author: ", $book->{author}, "\n";
    print "Publisher: ", $book->{publisher}, "\n";
    print "Year: ", $book->{year}, "\n";
  }

=head1 DESCRIPTION

This is a WWW::Scraper::ISBN driver that pulls data from
L<http://www.isbndb.com>. Consult L<WWW::Scraper::ISBN> for usage
details.

=cut

sub search {
  my( $self, $isbn ) = @_;
  $self->found(0);
  $self->book(undef);

  my( $details, $details_url ) = $self->_fetch( 'books', 'isbn' => $isbn, 'details' );
  my( $authors, $authors_url ) = $self->_fetch( 'books', 'isbn' => $isbn, 'authors' );

  return undef unless $details && $self->_contains_book_data($details);

  my $pubdata = $self->_get_pubdata($details);

  my %book = (
    isbn => $isbn,
    title => $self->_get_title($details),
    author => $self->_get_author($details, $authors),
    publisher => $pubdata->{publisher},
    location => $pubdata->{location},
    year => $pubdata->{year},
    _source_url => $details_url,
  );

  $self->book(\%book);
  $self->found(1);
  return $self->book;
}

sub _contains_book_data {
  my( $self, $doc ) = @_;
  return $doc->getElementsByTagName('BookData')->size > 0;
}

sub _get_title {
  my( $self, $doc ) = @_;
  my $long_title = eval { ($doc->findnodes('//TitleLong'))[0]->to_literal };
  my $short_title = eval { ($doc->findnodes('//Title'))[0]->to_literal };
  return $long_title || $short_title;
}

sub _get_author {
  my( $self, $details_doc, $authors_doc ) = @_;

  my $authors = $self->_get_all_authors($authors_doc);
  my $str = join '; ', @$authors;

  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  return $str;
}

sub _get_all_authors {
  my( $self, $authors ) = @_;
  my $people = $authors->findnodes('//Authors/Person');
  my @people;
  for( my $i = 0; $i < $people->size; $i++ ) {
    my $person = $people->get_node($i);
    push @people, $person->to_literal;
  }
  return \@people;
}

sub _get_pubdata {
  my( $self, $doc ) = @_;

  my $pubtext = $doc->findnodes('//PublisherText')->to_literal;
  my $details_ei = $doc->findnodes('//Details/@edition_info')->to_literal;

  my $year = '';
  if( $pubtext =~ /(\d{4})/ ) { $year = $1 }
  elsif( $details_ei =~ /(\d{4})/ ) { $year = $1 }

  my $pub_id = ($doc->findnodes('//PublisherText/@publisher_id'))[0]->to_literal;

  my $publisher = $self->_fetch( 'publishers', 'publisher_id', $pub_id, 'details' );
  my $data = ($publisher->findnodes('//PublisherData'))[0];

  return {
    publisher => ($data->findnodes('//Name'))[0]->to_literal,
    location => ($data->findnodes('//Details/@location'))[0]->to_literal,
    year => $year || ''
  };
}

sub _fetch {
  my( $self, @args ) = @_;
  my $parser = new XML::LibXML();
  my $url = $self->_url( @args );
  my $xml = $self->_fetch_data($url);
  my $doc = $parser->parse_string( $xml );
  return wantarray ? ( $doc, $url ) : $doc;
}

sub _fetch_data {
  my( $self, $url ) = @_;
  my $res = $user_agent->get($url);
  return unless $res->is_success;
  return $res->content;
}

sub _url {
  my( $self, $search_type, $search_field, $search_param, $results_type ) = @_;
  croak "no access key provided" unless $ACCESS_KEY;
  my $url = sprintf( 'http://isbndb.com/api/%s.xml?access_key=%s&index1=%s&results=%s&value1=%s',
                     $search_type, $ACCESS_KEY, $search_field, $results_type, $search_param );
  return $url;
}

=head1 SEE ALSO

L<WWW::Scraper::ISBN>

=head1 AUTHOR

David J. Iberri, C<< <diberri at cpan.org> >>

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

=head1 COPYRIGHT & LICENSE

Copyright 2006 David J. Iberri, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
