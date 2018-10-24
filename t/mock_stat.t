#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockFile ();
use Errno qw/ELOOP/;

note "_fh_to_file";

my @mocked_files;

push @mocked_files, Test::MockFile->file( '/foo/bar', "" );
push @mocked_files, Test::MockFile->file( '/bar/foo', "" );
open( my $fh,  "<", "/foo/bar" ) or die;
open( my $fh2, "<", "/bar/foo" ) or die;

is( Test::MockFile::_fh_to_file(),              undef,         "_fh_to_file()" );
is( Test::MockFile::_fh_to_file(0),             0,             "_fh_to_file(0)" );
is( Test::MockFile::_fh_to_file(''),            '',            "_fh_to_file('')" );
is( Test::MockFile::_fh_to_file(' '),           ' ',           "_fh_to_file(' ')" );
is( Test::MockFile::_fh_to_file('/etc/passwd'), '/etc/passwd', "_fh_to_file('/etc/passwd')" );

is( Test::MockFile::_fh_to_file($fh),  '/foo/bar', "_fh_to_file(\$fh)" );
is( Test::MockFile::_fh_to_file($fh2), '/bar/foo', "_fh_to_file(\$fh2)" );
close $fh;
close $fh2;
is( Test::MockFile::_fh_to_file($fh), undef, "_fh_to_file(\$fh) when closed." );

note "_find_file_or_fh";
push @mocked_files, Test::MockFile->symlink( '/abc', '/foo/bar' );
is( Test::MockFile::_find_file_or_fh('/abc'), '/abc', "_find_file_or_fh('/abc')" );
is( Test::MockFile::_find_file_or_fh( '/abc', 1 ), '/foo/bar', "_find_file_or_fh('/abc', 1) - follow" );

push @mocked_files, Test::MockFile->symlink( '/broken_link', '/not/a/file' );
like(
    dies { Test::MockFile::_find_file_or_fh( '/broken_link', 1 ) },
    qr{^Mocked file /broken_link points to unmocked file /not/a/file at },
    "_find_file_or_fh('/broken_link', 1) dies when /broken_link is mocked."
);

push @mocked_files, Test::MockFile->symlink( '/aaa', '/bbb' );
push @mocked_files, Test::MockFile->symlink( '/bbb', '/aaa' );
is( Test::MockFile::_find_file_or_fh( '/aaa', 1 ), undef, "_find_file_or_fh('/aaaa', 1) - with circular links" );
is( $!, "Too many levels of symbolic links", '$! text message' );
is( $! + 0, ELOOP, '$! is ELOOP' );

note "_mock_stat";

is( Test::MockFile::_mock_stat("/lib"), -1, "An unmocked file will return -1 to tell XS to handle it" );
is( Test::MockFile::_mock_stat(),       -1, "no args passes to XS" );
is( Test::MockFile::_mock_stat(""),     -1, "empty string passes to XS" );
is( Test::MockFile::_mock_stat(' '),    -1, "A space string passes to XS" );

my $basic_stat_return = array {
    item 0;
    item 0;
    item 0;
    item 0;
    item 0;
    item 0;
    item 0;
    item 0;
    item match qr/^\d\d\d\d+$/;
    item match qr/^\d\d\d\d+$/;
    item match qr/^\d\d\d\d+$/;
    item 4096;
    item 0;
};
is( [ Test::MockFile::_mock_stat('/foo/bar') ], $basic_stat_return, "/foo/bar mock stat" );

is( [ Test::MockFile::_mock_stat('/aaa') ], [], "/aaa mock stat when looped." );

push @mocked_files, Test::MockFile->file('/foo/baz');    # Missing file but mocked.
is( [ Test::MockFile::_mock_stat('/foo/baz') ], [], "/foo/baz mock stat when missing." );

done_testing();
exit;
