#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Fcntl qw( :seek O_RDONLY O_WRONLY O_CREAT O_TRUNC O_RDWR );

use Test::MockFile qw< nostrict >;

# File content used across tests: "ABCDEFGHIJ" (10 bytes)
my $content = "ABCDEFGHIJ";

{
    note "--- SEEK_SET (whence=0) ---";

    my $mock = Test::MockFile->file( '/fake/seek_set', $content );
    sysopen( my $fh, '/fake/seek_set', O_RDONLY ) or die;

    is( sysseek( $fh, 0, SEEK_SET ), "0 but true", "SEEK_SET to 0 returns '0 but true'" );

    is( sysseek( $fh, 5, SEEK_SET ), 5, "SEEK_SET to 5 returns 5" );
    my $buf = "";
    sysread( $fh, $buf, 3, 0 );
    is( $buf, "FGH", "Reading 3 bytes from position 5 gives FGH" );

    is( sysseek( $fh, 10, SEEK_SET ), 10, "SEEK_SET to 10 (EOF) returns 10" );

    is( sysseek( $fh, 11, SEEK_SET ), 0, "SEEK_SET beyond EOF returns 0 (failure)" );

    is( sysseek( $fh, -1, SEEK_SET ), 0, "SEEK_SET to negative returns 0 (failure)" );

    close $fh;
}

{
    note "--- SEEK_CUR (whence=1) ---";

    my $mock = Test::MockFile->file( '/fake/seek_cur', $content );
    sysopen( my $fh, '/fake/seek_cur', O_RDONLY ) or die;

    is( sysseek( $fh, 3, SEEK_SET ), 3, "Start at position 3" );
    is( sysseek( $fh, 4, SEEK_CUR ), 7, "SEEK_CUR +4 from 3 gives 7" );

    my $buf = "";
    sysread( $fh, $buf, 2, 0 );
    is( $buf, "HI", "Reading from position 7 gives HI" );

    # After sysread of 2 bytes, tell is at 9
    is( sysseek( $fh, -3, SEEK_CUR ), 6, "SEEK_CUR -3 from 9 gives 6" );

    is( sysseek( $fh, 0, SEEK_CUR ), 6, "SEEK_CUR 0 returns current position (6)" );

    # Try to seek before start of file
    is( sysseek( $fh, -100, SEEK_CUR ), 0, "SEEK_CUR before start of file returns 0" );

    # Try to seek beyond EOF
    is( sysseek( $fh, 100, SEEK_CUR ), 0, "SEEK_CUR beyond EOF returns 0" );

    close $fh;
}

{
    note "--- SEEK_END (whence=2) ---";

    my $mock = Test::MockFile->file( '/fake/seek_end', $content );
    sysopen( my $fh, '/fake/seek_end', O_RDONLY ) or die;

    is( sysseek( $fh, 0, SEEK_END ), 10, "SEEK_END with offset 0 = EOF position (10)" );

    is( sysseek( $fh, -3, SEEK_END ), 7, "SEEK_END -3 gives position 7" );
    my $buf = "";
    sysread( $fh, $buf, 3, 0 );
    is( $buf, "HIJ", "Reading 3 bytes from position 7 gives HIJ" );

    is( sysseek( $fh, -10, SEEK_END ), "0 but true", "SEEK_END -10 gives position 0 ('0 but true')" );

    is( sysseek( $fh, -11, SEEK_END ), 0, "SEEK_END before start returns 0 (failure)" );

    is( sysseek( $fh, 1, SEEK_END ), 0, "SEEK_END beyond file returns 0 (failure)" );

    close $fh;
}

{
    note "--- Invalid whence ---";

    my $mock = Test::MockFile->file( '/fake/seek_bad', $content );
    sysopen( my $fh, '/fake/seek_bad', O_RDONLY ) or die;

    like( dies { sysseek( $fh, 0, 3 ) }, qr/Invalid whence value/, "whence=3 dies with 'Invalid whence value'" );
    like( dies { sysseek( $fh, 0, -1 ) }, qr/Invalid whence value/, "whence=-1 dies with 'Invalid whence value'" );
    like( dies { sysseek( $fh, 0, 99 ) }, qr/Invalid whence value/, "whence=99 dies with 'Invalid whence value'" );

    close $fh;
}

{
    note "--- seek() via Perl builtin (not sysseek) ---";

    my $mock = Test::MockFile->file( '/fake/seek_builtin', $content );
    sysopen( my $fh, '/fake/seek_builtin', O_RDONLY ) or die;

    ok( seek( $fh, 5, SEEK_SET ), "seek() with SEEK_SET returns true" );
    is( sysseek( $fh, 0, SEEK_CUR ), 5, "tell position is 5 after seek()" );

    ok( seek( $fh, 2, SEEK_CUR ), "seek() with SEEK_CUR returns true" );
    is( sysseek( $fh, 0, SEEK_CUR ), 7, "tell position is 7 after relative seek()" );

    ok( seek( $fh, -2, SEEK_END ), "seek() with SEEK_END returns true" );
    is( sysseek( $fh, 0, SEEK_CUR ), 8, "tell position is 8 after SEEK_END -2" );

    close $fh;
}

{
    note "--- Empty file ---";

    my $mock = Test::MockFile->file( '/fake/seek_empty', "" );
    sysopen( my $fh, '/fake/seek_empty', O_RDONLY ) or die;

    is( sysseek( $fh, 0, SEEK_SET ), "0 but true", "SEEK_SET 0 on empty file returns '0 but true'" );
    is( sysseek( $fh, 0, SEEK_END ), "0 but true", "SEEK_END 0 on empty file returns '0 but true'" );
    is( sysseek( $fh, 0, SEEK_CUR ), "0 but true", "SEEK_CUR 0 on empty file returns '0 but true'" );
    is( sysseek( $fh, 1, SEEK_SET ), 0, "SEEK_SET 1 on empty file returns 0 (failure)" );

    close $fh;
}

{
    note "--- Seek after write ---";

    my $mock = Test::MockFile->file('/fake/seek_rw');
    sysopen( my $fh, '/fake/seek_rw', O_RDWR | O_CREAT | O_TRUNC ) or die;

    syswrite( $fh, "Hello World" );    # 11 bytes
    is( sysseek( $fh, 0, SEEK_SET ), "0 but true", "Seek back to start after write" );

    my $buf = "";
    sysread( $fh, $buf, 5, 0 );
    is( $buf, "Hello", "Read back what was written after seek" );

    is( sysseek( $fh, -5, SEEK_END ), 6, "SEEK_END -5 on written data gives position 6" );
    $buf = "";
    sysread( $fh, $buf, 5, 0 );
    is( $buf, "World", "Read 'World' from position 6" );

    close $fh;
}

is( \%Test::MockFile::files_being_mocked, {}, "No mock files are in cache" );

done_testing();
exit;
