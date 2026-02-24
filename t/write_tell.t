#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Fcntl qw( O_RDWR O_CREAT O_TRUNC O_WRONLY );

use Test::MockFile qw< nostrict >;

{
    note "--- tell() advances after print ---";

    my $mock = Test::MockFile->file('/fake/write_tell');
    open( my $fh, '>', '/fake/write_tell' ) or die;

    is( tell($fh), 0, "tell is 0 before any writes" );

    print $fh "Hello";
    is( tell($fh), 5, "tell is 5 after printing 'Hello'" );

    print $fh " World";
    is( tell($fh), 11, "tell is 11 after printing ' World'" );

    close $fh;
    is( $mock->contents, "Hello World", "Contents are correct" );
}

{
    note "--- tell() advances after printf ---";

    my $mock = Test::MockFile->file('/fake/printf_tell');
    open( my $fh, '>', '/fake/printf_tell' ) or die;

    printf $fh "%04d", 42;
    is( tell($fh), 4, "tell is 4 after printf '%04d'" );

    printf $fh "-%s-", "test";
    is( tell($fh), 10, "tell is 10 after second printf" );

    close $fh;
    is( $mock->contents, "0042-test-", "Contents are correct" );
}

{
    note "--- tell() advances after syswrite ---";

    my $mock = Test::MockFile->file('/fake/syswrite_tell');
    sysopen( my $fh, '/fake/syswrite_tell', O_WRONLY | O_CREAT | O_TRUNC ) or die;

    syswrite( $fh, "ABCDE", 5 );
    is( tell($fh), 5, "tell is 5 after syswrite of 5 bytes" );

    syswrite( $fh, "FGH", 3 );
    is( tell($fh), 8, "tell is 8 after syswrite of 3 more bytes" );

    close $fh;
    is( $mock->contents, "ABCDEFGH", "Contents are correct" );
}

{
    note "--- tell() after write then read (read+write mode) ---";

    my $mock = Test::MockFile->file('/fake/rw_tell');
    sysopen( my $fh, '/fake/rw_tell', O_RDWR | O_CREAT | O_TRUNC ) or die;

    syswrite( $fh, "Hello World", 11 );
    is( tell($fh), 11, "tell is 11 after writing 'Hello World'" );

    seek( $fh, 0, 0 );
    is( tell($fh), 0, "tell is 0 after seeking to start" );

    my $buf = "";
    read( $fh, $buf, 5 );
    is( $buf,      "Hello", "Read back 'Hello'" );
    is( tell($fh), 5,       "tell is 5 after reading 5 bytes" );
}

{
    note "--- tell() after append mode ---";

    my $mock = Test::MockFile->file( '/fake/append_tell', "existing" );
    open( my $fh, '>>', '/fake/append_tell' ) or die;

    print $fh " data";
    is( tell($fh), 13, "tell is 13 after appending to 'existing'" );

    close $fh;
    is( $mock->contents, "existing data", "Contents are correct" );
}

{
    note "--- printing undef does not change tell ---";

    my $mock = Test::MockFile->file('/fake/undef_tell');
    open( my $fh, '>', '/fake/undef_tell' ) or die;

    print $fh "ABC";
    is( tell($fh), 3, "tell is 3 after printing 'ABC'" );

    print $fh undef;
    is( tell($fh), 3, "tell unchanged after printing undef" );

    close $fh;
    is( $mock->contents, "ABC", "Contents are correct" );
}

{
    note "--- print with explicit output record separator ---";

    my $mock = Test::MockFile->file('/fake/ors_tell');
    open( my $fh, '>', '/fake/ors_tell' ) or die;

    {
        local $\ = "\n";
        print $fh "Hello";
    }
    is( tell($fh), 6, "tell is 6 after print with ORS (5 chars + newline)" );

    close $fh;
    is( $mock->contents, "Hello\n", "Contents include newline from output record separator" );
}

# Note: say() with tied filehandles does NOT append the newline via $\.
# Perl handles say's newline at the C level (pp_print) after the tied
# PRINT method returns, so it is never passed to PRINT. This is a known
# limitation of tied filehandles in Perl.

{
    note "--- +< mode: seek + print overwrites at tell position ---";

    my $mock = Test::MockFile->file( '/fake/rw_overwrite', "Hello World!" );
    open( my $fh, '+<', '/fake/rw_overwrite' ) or die;

    # Seek to position 6 and overwrite
    seek( $fh, 6, 0 );
    is( tell($fh), 6, "tell is 6 after seek" );

    print $fh "Perl!";
    is( tell($fh), 11, "tell is 11 after printing 5 bytes at position 6" );

    close $fh;
    is( $mock->contents, "Hello Perl!!", "Overwrite at position 6 replaces 'World' with 'Perl!'" );
}

{
    note "--- +< mode: seek + print does not extend past original when write fits ---";

    my $mock = Test::MockFile->file( '/fake/rw_exact', "ABCDEFGH" );
    open( my $fh, '+<', '/fake/rw_exact' ) or die;

    seek( $fh, 3, 0 );
    print $fh "XY";

    close $fh;
    is( $mock->contents, "ABCXYEGH", "Overwrite at position 3 replaces 2 bytes" );
}

{
    note "--- +< mode: print at tell 0 overwrites from start ---";

    my $mock = Test::MockFile->file( '/fake/rw_start', "old content" );
    open( my $fh, '+<', '/fake/rw_start' ) or die;

    # tell starts at 0
    print $fh "NEW";

    close $fh;
    is( $mock->contents, "NEW content", "Print at position 0 overwrites first 3 bytes" );
}

{
    note "--- +< mode: print extending past end grows the file ---";

    my $mock = Test::MockFile->file( '/fake/rw_extend', "short" );
    open( my $fh, '+<', '/fake/rw_extend' ) or die;

    seek( $fh, 3, 0 );
    print $fh "LONGER";

    close $fh;
    is( $mock->contents, "shoLONGER", "Print past end extends the file" );
    is( length( $mock->contents ), 9, "File length is 9" );
}

{
    note "--- >> mode: seek then print still appends ---";

    my $mock = Test::MockFile->file( '/fake/append_seek', "AAAA" );
    open( my $fh, '>>', '/fake/append_seek' ) or die;

    # Even after seeking to 0, append mode writes at end
    seek( $fh, 0, 0 );
    print $fh "BB";

    close $fh;
    is( $mock->contents, "AAAABB", "Append mode ignores seek position" );
}

{
    note "--- +< mode: interleaved read and write ---";

    my $mock = Test::MockFile->file( '/fake/rw_interleave', "Hello World" );
    open( my $fh, '+<', '/fake/rw_interleave' ) or die;

    # Read first 5 bytes
    my $buf;
    read( $fh, $buf, 5 );
    is( $buf,      "Hello", "Read 'Hello'" );
    is( tell($fh), 5,       "tell is 5 after read" );

    # Write at current position (overwrite ' World' with ' Perl!')
    print $fh " Perl!";
    is( tell($fh), 11, "tell is 11 after write" );

    close $fh;
    is( $mock->contents, "Hello Perl!", "Interleaved read+write produces correct output" );
}

{
    note "--- > mode: print writes at tell position (not append) ---";

    my $mock = Test::MockFile->file('/fake/write_overwrite');
    open( my $fh, '>', '/fake/write_overwrite' ) or die;

    # Write initial content
    print $fh "ABCDEFGH";
    is( tell($fh), 8, "tell is 8 after initial write" );

    # Seek back and overwrite
    seek( $fh, 2, 0 );
    print $fh "XY";
    is( tell($fh), 4, "tell is 4 after overwrite" );

    close $fh;
    is( $mock->contents, "ABXYEFGH", "Overwrite in > mode at seek position" );
}

is( \%Test::MockFile::files_being_mocked, {}, "No mock files are in cache" );

done_testing();
exit;
