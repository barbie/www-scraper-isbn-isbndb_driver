package WWW::Scraper::ISBN::ISBNdb_Driver;
use base 'WWW::Scraper::ISBN::Driver';

use strict;
use warnings;

use XML::DOM;
use Carp;

our $VERSION = '0.03';
our $ACCESS_KEY = undef;

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
L<http://www.isbndb.com>. Consult L<WWW::Scraper::ISBN> for usage.

=cut

sub search {
  my( $self, $isbn ) = @_;
  $self->found(0);
  $self->book(undef);

  my( $doc, $url ) = $self->_fetch( 'books', 'isbn', $isbn );
  return undef unless $doc;

  my $pubdata = $self->_get_pubdata($doc);

  my %book = (
    isbn => $isbn,
    title => $self->_get_title($doc),
    author => $self->_get_author($doc),
    publisher => $pubdata->{publisher},
    location => $pubdata->{location},
    year => $pubdata->{year},
    _source_url => $url,
  );

  $self->book(\%book);
  $self->found(1);
  return $self->book;
}

sub _get_title {
  my( $self, $doc ) = @_;
  return $doc->getElementsByTagName('TitleLong')->item(0)->getChildNodes->item(0)
    ? $doc->getElementsByTagName('TitleLong')->item(0)->getChildNodes->item(0)->toString()
    : $doc->getElementsByTagName('Title')->item(0)->getChildNodes->item(0)->toString();
}

sub _get_author {
  my( $self, $doc ) = @_;
  return $doc->getElementsByTagName('AuthorsText')->item(0)->getChildNodes->item(0)->toString();
}

sub _get_pubdata {
  my( $self, $doc ) = @_;

  my $pubtext = $doc->getElementsByTagName('PublisherText')->item(0)->getChildNodes->item(0)->toString();
  my $year = $1 if $pubtext =~ /(\d{4})/;

  my $pub_id = $doc->getElementsByTagName('PublisherText')->item(0)->getAttributes->getNamedItem('publisher_id')->getValue();
  my $data = $self->_fetch( 'publishers', 'publisher_id', $pub_id )->getElementsByTagName('PublisherData')->item(0);
  return {
    publisher => $data->getElementsByTagName('Name')->item(0)->getChildNodes->item(0)->toString(),
    location => $data->getElementsByTagName('Details')->item(0)->getAttributes->getNamedItem('location')->getValue(),
    year => $year || ''
  };
}

sub _fetch {
  my( $self, @args ) = @_;
  my $parser = new XML::DOM::Parser();
  my $url = $self->_url( @args );
  my $doc = $parser->parsefile( $url );
  return wantarray ? ( $doc, $url ) : $doc;
}

sub _url {
  my( $self, $search_type, $search_field, $search_param ) = @_;
  croak "no access key provided" unless $ACCESS_KEY;
  return sprintf 'http://isbndb.com/api/%s.xml?access_key=%s&index1=%s&results=details&value1=%s', $search_type, $ACCESS_KEY, $search_field, $search_param;
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
