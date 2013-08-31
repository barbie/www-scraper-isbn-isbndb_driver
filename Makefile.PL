use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WWW::Scraper::ISBN::ISBNdb_Driver',
    AUTHOR              => 'David J. Iberri <diberri@cpan.org>',
    VERSION_FROM        => 'lib/WWW/Scraper/ISBN/ISBNdb_Driver.pm',
    ABSTRACT_FROM       => 'lib/WWW/Scraper/ISBN/ISBNdb_Driver.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        # Business::ISBN v2.01 or greater is required for isbn-13 support
        'WWW::Scraper::ISBN'         => 0,
        'WWW::Scraper::ISBN::Driver' => 0.15,
        'LWP::UserAgent' => 0,
        'XML::DOM'       => 0,
        'Test::More'     => 0, 
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Scraper-ISBN-ISBNdb_Driver-*' },
);
