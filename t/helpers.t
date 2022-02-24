#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockFile qw< nostrict >;    # Everything below this can have its open overridden.

like( dies { Test::MockFile::_generate_mode( 0700, 'lemming' ) }, qr/^Unknown file type lemming at /, 'unknown file type dies' );

my @tests = (
    [ 0755, 022, 'dir',     '40755',  'basic 755 mask on dirs' ],
    [ 0700, 022, 'dir',     '40700',  'basic 644 mask on dirs' ],
    [ 0755, 022, 'file',    '100755', 'basic 755 mask on files' ],
    [ 0755, 077, 'file',    '100700', '755 mask on files with 077 umask' ],
    [ 0755, 007, 'file',    '100750', '755 mask on files with 007 umask' ],
    [ 0644, 022, 'file',    '100644', 'basic 644 mask on files' ],
    [ 0777, 022, 'symlink', '120777', 'basic 777 mask on symlinks. Umask isn\'t used for symlinks' ],
);

foreach my $test (@tests) {
    umask $test->[1];
    my $got = Test::MockFile::_generate_mode( $test->[0], $test->[2] );
    is( sprintf( "%o", $got ), $test->[3], $test->[4] );
}

done_testing();
exit;
