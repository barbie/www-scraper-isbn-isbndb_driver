#!perl -T

use Test::More;

my $access_key = $ENV{ISBNDB_ACCESS_KEY};

if( $access_key ) {
  plan tests => 12;
} else {
  plan skip_all => 'no isbndb.com access key provided in ISBNDB_ACCESS_KEY env variable';
}

use WWW::Scraper::ISBN;
use ExtUtils::MakeMaker;

my $scraper = new WWW::Scraper::ISBN();
$scraper->drivers( qw/ ISBNdb / );

{
  no warnings;
  $WWW::Scraper::ISBN::ISBNdb_Driver::ACCESS_KEY = $access_key;
}

my( $res, $book );

$res = $scraper->search( '0596101058' );
$book = $res->book;
is( $book->{isbn}, '0596101058' );
is( $book->{title}, "Learning Perl", 'title' );
is( $book->{author}, "brian d foy; Schwartz, Randal L.; Tom Phoenix", 'author' );
is( $book->{publisher}, "O'Reilly", 'publisher' );
is( $book->{year}, '2005', 'year' );

$res = $scraper->search( '9780764563737' );
ok( $res, 'got res from isbn13' );

$res = $scraper->search( '0-07-048074-5' );
my $error = $@ || '';
ok( $error !~ /getChildNodes/, 'no getChildNodes error if XML does not contain BookData' );

$res = $scraper->search('0-07-139140-1');
$book = $res->found ? $res->book : undef;
ok( $book, "found harrison's" );
is( $book->{title}, "Harrison's principles of internal medicine", "harrison's title" );
is( $book->{author}, "Harrison, Tinsley Randolph; Dennis L. Kasper", "harrison's author" );

$res = $scraper->search('074328951X');
$book = $res->found ? $res->book : undef;
ok( $book, "found copernicus' secret" );
is( $book->{year}, '2007', "matched year using details/edition_info attribute" );
