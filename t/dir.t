#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use File::Temp qw/tempfile tempdir/;
use File::Basename;

use Errno qw/ENOENT EBADF/;

use Test::MockFile;    # Everything below this can have its open overridden.

my $temp_dir = tempdir( CLEANUP => 1 );
my ( undef, $filename ) = tempfile( DIR => $temp_dir );

note "-------------- REAL MODE --------------";
is( -d $temp_dir, 1, "Temp is created on disk." );
is( opendir( my $dir_fh, $temp_dir ), 1, "$temp_dir can be read" );
is( scalar readdir $dir_fh, ".",  "Read . from readdir" );
is( scalar readdir $dir_fh, "..", "Read .. from readdir" );
my $base = basename $filename;
is( scalar readdir $dir_fh, $base, "Read $base from readdir" );
is( scalar readdir $dir_fh, undef, "undef when nothing left from readdir." );
my ( undef, $f2 ) = tempfile( DIR => $temp_dir );
$base = basename $f2;
ok( -e $f2, "File 2 ($f2) exists but...." );
is( scalar readdir $dir_fh, undef, "readdir doesn't see it since it's there after the opendir." );
is( closedir $dir_fh,       1,     "close the fake dir handle" );

like( warning { readdir($dir_fh) }, qr/^readdir\(\) attempted on invalid dirhandle __ANONIO__ /, "warn on readdir when file handle is closed." );

is( opendir( my $bad_fh, "/not/a/valid/path/kdshjfkjd" ), undef, "opendir on a bad path returns false" );
is( $! + 0, ENOENT, '$! numeric is right.' );
is( $!, "No such file or directory", '$! text is right.' );

like( dies { readdir("abc"); }, qr/^Bad symbol for dirhandle at/, "Dies if string passed instead of dir fh" );

my ( $real_fh, $f3 ) = tempfile( DIR => $temp_dir );
like( warning { readdir($real_fh) }, qr/^readdir\(\) attempted on invalid dirhandle \$fh/, "We only warn if the file handle or glob is invalid." );

note "-------------- MOCK MODE --------------";
my $bar = Test::MockFile->dir( $temp_dir, [qw/. .. abc def/] );

is( opendir( $dir_fh, $temp_dir ), 1, "Mocked temp dir opens and returns true" );
is( scalar readdir $dir_fh, ".",   "Read .  from fake readdir" );
is( scalar readdir $dir_fh, "..",  "Read .. from fake readdir" );
is( telldir $dir_fh,        2,     "tell dir in the middle of fake readdir is right." );
is( scalar readdir $dir_fh, "abc", "Read abc from fake readdir" );
is( scalar readdir $dir_fh, "def", "Read def from fake readdir" );
is( telldir $dir_fh,        4,     "tell dir at the end of fake readdir is right." );
is( scalar readdir $dir_fh, undef, "Read from fake readdir but no more in the list." );
is( scalar readdir $dir_fh, undef, "Read from fake readdir but no more in the list." );
is( scalar readdir $dir_fh, undef, "Read from fake readdir but no more in the list." );
is( scalar readdir $dir_fh, undef, "Read from fake readdir but no more in the list." );

is( rewinddir($dir_fh), 1, "rewinddir returns true." );
is( telldir $dir_fh,    0, "telldir afer rewinddir is right." );
is( [ readdir $dir_fh ], [qw/. .. abc def/], "Read the whole dir from fake readdir after rewinddir" );
is( telldir $dir_fh, 4, "tell dir at the end of fake readdir is right." );
is( seekdir( $dir_fh, 1 ), 1, "seekdir returns where it sought." );
is( [ readdir $dir_fh ], [qw/.. abc def/], "Read the whole dir from fake readdir after seekdir" );
closedir($dir_fh);

#
#isa_ok( $fh, "IO::File", '$fh is a IO::File' );
#like( "$fh", qr/^IO::File=GLOB\(0x[0-9a-f]+\)$/, '$fh stringifies to a IO::File GLOB' );
#is( <$fh>,          "abc\n",           '1st read on $fh is "abc\n"' );
#is( <$fh>,          "def\n",           '2nd read on $fh is "def\n"' );
#is( readline($fh),  "ghi\n",           '3rd read on $fh via readline is "ghi\n"' );
#is( <$fh>,          undef,             '4th read on $fh undef at EOF' );
#is( <$fh>,          undef,             '5th read on $fh undef at EOF' );
#is( <$fh>,          undef,             '6th read on $fh undef at EOF' );
#is( $bar->contents, "abc\ndef\nghi\n", '$foo->contents' );
#
#$bar->contents( join( "\n", qw/abc def jkl mno pqr/ ) );
#is( <$fh>, "mno\n", '7th read on $fh is "mno\n"' );
#is( <$fh>, "pqr",   '7th read on $fh is "pqr"' );
#is( <$fh>, undef,   '8th read on $fh undef at EOF' );
#is( <$fh>, undef,   '9th read on $fh undef at EOF' );
#
#{
#    my $warn_msg;
#    local $SIG{__WARN__} = sub { $warn_msg = shift };
#    is( print( {$fh} "TEST" ), undef, "Fails to write to a read handle in mock mode." );
#    is( $! + 0, EBADF, q{$! when the file is written to and it's a read file handle.} );
#    like( $warn_msg, qr{^Filehandle .+? opened only for input at .+? line \d+\.$}, "Warns about writing to a read file handle" );
#}
#
#close $fh;
#ok(!exists $Test::MockFile::files_being_mocked{$filename}->{'fh'}, "file handle clears from files_being_mocked hash when it goes out of scope.");
#
#undef $bar;
#is(scalar %Test::MockFile::files_being_mocked, 0, "files_being_mocked empties when \$bar is cleared");
#
#note "-------------- REAL MODE --------------";
#is( open( $fh_real, '<', $filename ), 1, "Once the mock file object is cleared, the next open reverts to the file on disk." );
#like( "$fh_real", qr/^GLOB\(0x[0-9a-f]+\)$/, '$fh2 stringifies to a GLOB' );
#is( <$fh_real>, "not\n",    " ... line 1" );
#is( <$fh_real>, "mocked\n", " ... line 1" );
#close $fh_real;
#
## Missing file handling
#{
#    local $!;
#    unlink $filename;
#}
#
#my $missing_error = 'No such file or directory';
#undef $fh;
#is( open( $fh, '<', $filename ), undef, qq{Can't open a missing file "$filename"} );
#is( $! + 0, ENOENT, 'What $! looks like when failing to open the missing file.' );
#
#note "-------------- MOCK MODE --------------";
#my $baz = Test::MockFile->file($filename);
#is( open( $fh, '<', $filename ), undef, qq{Can't open a missing file "$filename"} );
#is( $! + 0, ENOENT, 'What $! looks like when failing to open the missing file.' );

done_testing();
exit;
