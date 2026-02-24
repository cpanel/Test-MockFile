#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Errno qw/ENOENT EISDIR ENOTDIR ENOTEMPTY EXDEV/;
use File::Temp qw/tempfile/;

use Test::MockFile qw< nostrict >;

subtest 'rename mocked file to new mocked path' => sub {
    my $mock = Test::MockFile->file( '/mock/old.txt', 'hello world' );
    my $dest = Test::MockFile->file('/mock/new.txt');

    ok( -e '/mock/old.txt',  'source exists before rename' );
    ok( !-e '/mock/new.txt', 'destination does not exist before rename' );

    $! = 0;
    is( rename( '/mock/old.txt', '/mock/new.txt' ), 1, 'rename returns 1 on success' );
    is( $! + 0, 0, '$! remains 0' );

    ok( !-e '/mock/old.txt', 'source no longer exists after rename' );
    ok( -e '/mock/new.txt',  'destination exists after rename' );

    # Content should be preserved
    open my $fh, '<', '/mock/new.txt' or die "open: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is( $content, 'hello world', 'content is preserved after rename' );
};

subtest 'rename non-existent mocked file fails with ENOENT' => sub {
    my $src  = Test::MockFile->file('/mock/gone.txt');    # no content = does not exist
    my $dest = Test::MockFile->file('/mock/target.txt');

    $! = 0;
    is( rename( '/mock/gone.txt', '/mock/target.txt' ), 0, 'rename returns 0' );
    is( $! + 0, ENOENT, '$! is ENOENT' );
};

subtest 'rename mocked file over existing mocked file replaces it' => sub {
    my $src  = Test::MockFile->file( '/mock/src.txt',  'new content' );
    my $dest = Test::MockFile->file( '/mock/dest.txt', 'old content' );

    ok( -e '/mock/src.txt',  'source exists' );
    ok( -e '/mock/dest.txt', 'destination exists' );

    $! = 0;
    is( rename( '/mock/src.txt', '/mock/dest.txt' ), 1, 'rename returns 1' );
    is( $! + 0, 0, '$! remains 0' );

    ok( !-e '/mock/src.txt', 'source gone after rename' );
    ok( -e '/mock/dest.txt', 'destination exists' );

    open my $fh, '<', '/mock/dest.txt' or die "open: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is( $content, 'new content', 'destination has source content' );
};

subtest 'rename file over directory fails with EISDIR' => sub {
    my $src = Test::MockFile->file( '/mock/afile.txt', 'data' );
    my $dir = Test::MockFile->new_dir('/mock/adir');

    $! = 0;
    is( rename( '/mock/afile.txt', '/mock/adir' ), 0, 'rename returns 0' );
    is( $! + 0, EISDIR, '$! is EISDIR' );

    ok( -e '/mock/afile.txt', 'source file still exists' );
    ok( -d '/mock/adir',      'directory still exists' );
};

subtest 'rename directory over file fails with ENOTDIR' => sub {
    my $dir  = Test::MockFile->new_dir('/mock/mydir');
    my $file = Test::MockFile->file( '/mock/myfile.txt', 'data' );

    $! = 0;
    is( rename( '/mock/mydir', '/mock/myfile.txt' ), 0, 'rename returns 0' );
    is( $! + 0, ENOTDIR, '$! is ENOTDIR' );

    ok( -d '/mock/mydir',      'source dir still exists' );
    ok( -e '/mock/myfile.txt', 'destination file still exists' );
};

subtest 'rename directory over non-empty directory fails with ENOTEMPTY' => sub {
    my $src_dir  = Test::MockFile->new_dir('/mock/srcdir');
    my $dest_dir = Test::MockFile->new_dir('/mock/destdir');
    my $child    = Test::MockFile->file( '/mock/destdir/child.txt', 'x' );

    $! = 0;
    is( rename( '/mock/srcdir', '/mock/destdir' ), 0, 'rename returns 0' );
    is( $! + 0, ENOTEMPTY, '$! is ENOTEMPTY' );

    ok( -d '/mock/srcdir',  'source dir still exists' );
    ok( -d '/mock/destdir', 'destination dir still exists' );
};

subtest 'rename directory over empty directory succeeds' => sub {
    my $src_dir  = Test::MockFile->new_dir('/mock/dir1');
    my $dest_dir = Test::MockFile->new_dir('/mock/dir2');

    $! = 0;
    is( rename( '/mock/dir1', '/mock/dir2' ), 1, 'rename returns 1' );
    is( $! + 0, 0, '$! remains 0' );

    ok( !-d '/mock/dir1', 'source dir gone' );
    ok( -d '/mock/dir2',  'destination dir exists' );
};

subtest 'rename unmocked file passes through to CORE' => sub {
    my ( $fh, $real_file ) = tempfile( CLEANUP => 1 );
    print $fh "real data";
    close $fh;

    my ( undef, $real_dest ) = tempfile( CLEANUP => 1 );
    CORE::unlink($real_dest);    # remove so rename can create it

    $! = 0;
    is( rename( $real_file, $real_dest ), 1, 'rename of real file returns 1' );
    is( $! + 0, 0, '$! remains 0' );

    ok( !-e $real_file, 'source real file is gone' );
    ok( -e $real_dest,  'destination real file exists' );

    CORE::unlink($real_dest);
};

subtest 'rename real file to mocked path fails with EXDEV' => sub {
    my ( $fh, $real_file ) = tempfile( CLEANUP => 1 );
    print $fh "real data";
    close $fh;

    my $mock_dest = Test::MockFile->file('/mock/cross.txt');

    $! = 0;
    is( rename( $real_file, '/mock/cross.txt' ), 0, 'rename returns 0' );
    is( $! + 0, EXDEV, '$! is EXDEV' );

    ok( -e $real_file, 'real source file still exists' );

    CORE::unlink($real_file);
};

subtest 'rename mocked file to unmocked path moves mock' => sub {
    my $mock = Test::MockFile->file( '/mock/moveme.txt', 'portable' );

    # Destination is not pre-mocked — the mock should move there
    $! = 0;
    is( rename( '/mock/moveme.txt', '/mock/moved.txt' ), 1, 'rename returns 1' );
    is( $! + 0, 0, '$! remains 0' );

    ok( !-e '/mock/moveme.txt', 'source is gone' );

    # The mock object moved to the new path — stat should work
    ok( -e '/mock/moved.txt', 'destination exists' );
};

subtest 'rename to same path is a no-op success' => sub {
    my $mock = Test::MockFile->file( '/mock/same.txt', 'unchanged' );

    $! = 0;
    is( rename( '/mock/same.txt', '/mock/same.txt' ), 1, 'rename returns 1' );
    is( $! + 0, 0, '$! remains 0' );

    ok( -e '/mock/same.txt', 'file still exists' );

    open my $fh, '<', '/mock/same.txt' or die "open: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is( $content, 'unchanged', 'content is preserved' );
};

subtest 'rename symlink moves the symlink entry, not target' => sub {
    my $target = Test::MockFile->file( '/mock/target.txt', 'target data' );
    my $link   = Test::MockFile->symlink( '/mock/target.txt', '/mock/mylink' );
    my $dest   = Test::MockFile->file('/mock/newlink');

    ok( -l '/mock/mylink', 'symlink exists before rename' );

    $! = 0;
    is( rename( '/mock/mylink', '/mock/newlink' ), 1, 'rename returns 1' );
    is( $! + 0, 0, '$! remains 0' );

    ok( !-l '/mock/mylink', 'old symlink is gone' );
    ok( -e '/mock/target.txt', 'target file still exists' );
};

done_testing();
