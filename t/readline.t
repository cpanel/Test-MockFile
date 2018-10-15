#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::MockFile;    # Everything below this can have its open overridden.

use File::Temp qw/tempfile/;

my ( $fh_real, $filename ) = tempfile();
print {$fh_real} "not\nmocked\n";
close $fh_real;

is( -s $filename, 11, "Temp file is on disk and right size" );
is( open( my $fh_real, '<', $filename ), 1, "Open a real file written by File::Temp" );
like( "$fh_real", qr/^GLOB\(0x[0-9a-f]+\)$/, '$fh2 stringifies to a GLOB' );
is( <$fh_real>, "not\n",    " ... line 1" );
is( <$fh_real>, "mocked\n", " ... line 1" );
close $fh_real;

my $bar = Test::MockFile->file( $filename, "abc\ndef\nghi\n" );
is( open( my $fh, '<', $filename ), 1, "Mocked temp file opens and returns true" );
isa_ok( $fh, "IO::File", '$fh is a IO::File' );
like( "$fh", qr/^IO::File=GLOB\(0x[0-9a-f]+\)$/, '$fh stringifies to a IO::File GLOB' );
is( <$fh>,          "abc\n",           '1st read on $fh is "abc\n"' );
is( <$fh>,          "def\n",           '2nd read on $fh is "def\n"' );
is( readline($fh),  "ghi\n",           '3rd read on $fh via readline is "ghi\n"' );
is( <$fh>,          undef,             '4th read on $fh undef at EOF' );
is( <$fh>,          undef,             '5th read on $fh undef at EOF' );
is( <$fh>,          undef,             '6th read on $fh undef at EOF' );
is( $bar->contents, "abc\ndef\nghi\n", '$foo->contents' );

$bar->contents( join( "\n", qw/abc def jkl mno pqr/ ) );
is( <$fh>, "mno\n", '7th read on $fh is "mno\n"' );
is( <$fh>, "pqr",   '7th read on $fh is "pqr"' );
is( <$fh>, undef,   '8th read on $fh undef at EOF' );
is( <$fh>, undef,   '9th read on $fh undef at EOF' );

undef $bar;

is( open( $fh_real, '<', $filename ), 1, "Once the mock file object is cleared, the next open reverts to the file on disk." );
like( "$fh_real", qr/^GLOB\(0x[0-9a-f]+\)$/, '$fh2 stringifies to a GLOB' );
is( <$fh_real>, "not\n",    " ... line 1" );
is( <$fh_real>, "mocked\n", " ... line 1" );
close $fh_real;

done_testing();
