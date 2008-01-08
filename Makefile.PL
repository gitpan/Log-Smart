use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Log::Smart',
    AUTHOR              => 'Kazuhiro Shibuya <k42uh1r0@gmail.com>',
    VERSION_FROM        => 'lib/Log/Smart.pm',
    ABSTRACT_FROM       => 'lib/Log/Smart.pm',
    LICENSE             => 'perl',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Log-Smart-*' },
);
