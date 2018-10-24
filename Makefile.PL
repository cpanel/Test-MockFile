use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'Test::MockFile',
    AUTHOR             => q{Todd Rinaldo <toddr@cpanel.net>},
    VERSION_FROM       => 'lib/Test/MockFile.pm',
    ABSTRACT_FROM      => 'lib/Test/MockFile.pm',
    LICENSE            => 'artistic_2',
    PL_FILES           => {},
    MIN_PERL_VERSION   => '5.006',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    BUILD_REQUIRES => {
        'Test::More'                => '0',
        'Test2::Bundle::Extended'   => '0',
        'Test2::Tools::Explain'     => '0',
        'Test2::Plugin::NoWarnings' => '0',
        'File::Slurper'             => 0,
    },
    PREREQ_PM => {
        'Overload::FileCheck' => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Test-MockFile-*' },
    'META_MERGE' => {
        'meta-spec' => { version => 2 },
        "resources" => {
            "bugtracker" => { web => "https://github.com/CpanelInc/Test-MockFile/issues" },
            "repository" => {
                "type" => "git",
                "url" => "https://github.com/CpanelInc/Test-MockFile.git",
                "web" => "https://github.com/CpanelInc/Test-MockFile"
            },
        },
    },
);
