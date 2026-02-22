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
    note "--- say() advances tell (includes newline) ---";

    my $mock = Test::MockFile->file('/fake/say_tell');
    open( my $fh, '>', '/fake/say_tell' ) or die;

    say $fh "Hello";
    is( tell($fh), 6, "tell is 6 after say 'Hello' (5 chars + newline)" );

    close $fh;
    is( $mock->contents, "Hello\n", "Contents include newline from say" );
}

is( \%Test::MockFile::files_being_mocked, {}, "No mock files are in cache" );

done_testing();
exit;
