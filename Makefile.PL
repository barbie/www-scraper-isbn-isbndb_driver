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
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Scraper-ISBN-ISBNdb_Driver-*' },
);
