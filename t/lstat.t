#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Errno qw/ENOENT EBADF/;

use Test::MockFile;    # Everything below this can have its open overridden.

use File::Temp qw/tempfile/;

my ( $fh_real, $filename ) = tempfile();
print {$fh_real} "not\nmocked\n";
close $fh_real;

{
    note "-------------- REAL MODE --------------";
    my @stat = lstat($filename);
    is($stat[7], 11, "The temp file on disk is 11 bytes");
}


{
    note "-------------- MOCK MODE --------------";
    my $bar = Test::MockFile->file( $filename, "z" x 22 );
    my @stat = lstat($filename);
    is($stat[7], 22, "Size of fake file comes back right.")
}

{
    note "-------------- REAL MODE --------------";
    my @stat = lstat($filename);
    is($stat[7], 11, "The temp file on disk re-asserts for lstat the second \$bar goes out of scope.");
}


done_testing();
exit;