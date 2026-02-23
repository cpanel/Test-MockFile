#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Errno qw/ELOOP ENOTEMPTY ENOENT/;
use Fcntl;

use Test::MockFile qw< nostrict >;

subtest "sysopen O_NOFOLLOW on symlink sets ELOOP" => sub {
    my $target = Test::MockFile->file( '/tmp/real_file', 'data' );
    my $link   = Test::MockFile->symlink( '/tmp/real_file', '/tmp/link_to_file' );

    # O_NOFOLLOW on a regular file should work
    $! = 0;
    ok( sysopen( my $fh, '/tmp/real_file', O_RDONLY | O_NOFOLLOW ), "sysopen O_NOFOLLOW on regular file succeeds" );
    close $fh if $fh;

    # O_NOFOLLOW on a symlink should fail with ELOOP
    $! = 0;
    ok( !sysopen( my $fh2, '/tmp/link_to_file', O_RDONLY | O_NOFOLLOW ), "sysopen O_NOFOLLOW on symlink fails" );
    is( $! + 0, ELOOP, "\$! is ELOOP (not hardcoded 40)" ) or diag "Got errno: " . ( $! + 0 ) . " ($!)";
};

subtest "rmdir non-empty directory sets ENOTEMPTY" => sub {
    my $dir  = Test::MockFile->dir('/tmp/test_dir');
    my $file = Test::MockFile->file( '/tmp/test_dir/child', 'content' );

    mkdir('/tmp/test_dir');

    $! = 0;
    ok( !rmdir('/tmp/test_dir'), "rmdir on non-empty directory fails" );
    is( $! + 0, ENOTEMPTY, "\$! is ENOTEMPTY (not hardcoded 39)" ) or diag "Got errno: " . ( $! + 0 ) . " ($!)";
};

subtest "syswrite with non-numeric length warns" => sub {
    my $mock = Test::MockFile->file('/tmp/write_test');
    sysopen( my $fh, '/tmp/write_test', O_WRONLY | O_CREAT | O_TRUNC ) or die;

    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };

    my $ret = syswrite( $fh, "hello", "abc" );
    is( $ret, 0, "syswrite with non-numeric len returns 0" );
    ok( scalar @warnings >= 1, "got a warning" );
    like( $warnings[0], qr/isn't numeric/, "warning mentions non-numeric argument" ) if @warnings;

    close $fh;
};

subtest "syswrite with negative length dies" => sub {
    my $mock = Test::MockFile->file('/tmp/write_test2');
    sysopen( my $fh, '/tmp/write_test2', O_WRONLY | O_CREAT | O_TRUNC ) or die;

    ok(
        dies { syswrite( $fh, "hello", -1 ) },
        "syswrite with negative length dies"
    );
    like( $@, qr/Negative length/, "error message mentions negative length" );

    close $fh;
};

subtest "syswrite with offset outside string dies" => sub {
    my $mock = Test::MockFile->file('/tmp/write_test3');
    sysopen( my $fh, '/tmp/write_test3', O_WRONLY | O_CREAT | O_TRUNC ) or die;

    ok(
        dies { syswrite( $fh, "hello", 2, 100 ) },
        "syswrite with offset beyond string dies"
    );
    like( $@, qr/Offset outside string/, "error message mentions offset" );

    close $fh;
};

subtest "syswrite with valid negative offset works" => sub {
    my $mock = Test::MockFile->file('/tmp/write_test4');
    sysopen( my $fh, '/tmp/write_test4', O_WRONLY | O_CREAT | O_TRUNC ) or die;

    # -3 from end of "hello" (len 5) = position 2, write 2 chars = "ll"
    is( syswrite( $fh, "hello", 2, -3 ), 2, "syswrite with negative offset returns correct byte count" );
    is( $mock->contents, "ll", "correct substring written with negative offset" );

    close $fh;
};

subtest "syswrite with too-negative offset dies" => sub {
    my $mock = Test::MockFile->file('/tmp/write_test5');
    sysopen( my $fh, '/tmp/write_test5', O_WRONLY | O_CREAT | O_TRUNC ) or die;

    ok(
        dies { syswrite( $fh, "hello", 2, -10 ) },
        "syswrite with offset before start of string dies"
    );
    like( $@, qr/Offset outside string/, "error message mentions offset" );

    close $fh;
};

done_testing();
