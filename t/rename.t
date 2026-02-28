#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Errno qw/ENOENT EISDIR ENOTDIR/;

use Test::MockFile qw< nostrict >;

note "-------------- rename: basic file rename --------------";
{
    my $old = Test::MockFile->file( '/mock/old', 'content' );
    my $new = Test::MockFile->file('/mock/new');

    ok( rename( '/mock/old', '/mock/new' ), 'rename returns true' );
    is( $old->contents, undef,     'old file contents cleared' );
    is( $new->contents, 'content', 'new file has old contents' );
}

note "-------------- rename: non-existent source --------------";
{
    my $old = Test::MockFile->file('/mock/noexist');
    my $new = Test::MockFile->file('/mock/dest');

    ok( !rename( '/mock/noexist', '/mock/dest' ), 'rename fails for non-existent source' );
    is( $! + 0, ENOENT, 'errno is ENOENT' );
}

note "-------------- rename: overwrite existing file --------------";
{
    my $old = Test::MockFile->file( '/mock/src', 'new content' );
    my $new = Test::MockFile->file( '/mock/dst', 'old content' );

    ok( rename( '/mock/src', '/mock/dst' ), 'rename overwrites existing file' );
    is( $new->contents, 'new content', 'destination has new contents' );
    is( $old->contents, undef,         'source is gone' );
}

note "-------------- rename: file to existing directory fails --------------";
{
    my $old = Test::MockFile->file( '/mock/file', 'data' );
    my $dir = Test::MockFile->new_dir('/mock/dir');

    ok( !rename( '/mock/file', '/mock/dir' ), 'cannot rename file over directory' );
    is( $! + 0, EISDIR, 'errno is EISDIR' );
}

note "-------------- rename: preserves file mode --------------";
{
    my $old = Test::MockFile->file( '/mock/moded', 'data', { mode => 0755 } );
    my $new = Test::MockFile->file('/mock/modedest');

    my $old_mode = $old->{'mode'};
    ok( rename( '/mock/moded', '/mock/modedest' ), 'rename preserves mode' );
    is( $new->{'mode'}, $old_mode, 'destination has source mode' );
}

note "-------------- rename: empty directory rename --------------";
{
    my $old = Test::MockFile->new_dir('/mock/olddir');
    my $new = Test::MockFile->dir('/mock/newdir');

    ok( rename( '/mock/olddir', '/mock/newdir' ), 'rename empty directory works' );
    ok( !$old->exists,                            'old dir no longer exists' );
    ok( $new->exists,                             'new dir exists' );
}

note "-------------- rename: symlink rename --------------";
{
    my $target = Test::MockFile->file( '/mock/target', 'data' );
    my $link   = Test::MockFile->symlink( '/mock/target', '/mock/link' );
    my $dest   = Test::MockFile->file('/mock/linkdest');

    ok( rename( '/mock/link', '/mock/linkdest' ), 'rename symlink works' );
    ok( !$link->is_link || !defined $link->readlink, 'old symlink is gone' );
}

note "-------------- rename: dir over existing file fails --------------";
{
    my $dir  = Test::MockFile->new_dir('/mock/adir');
    my $file = Test::MockFile->file( '/mock/afile', 'data' );

    ok( !rename( '/mock/adir', '/mock/afile' ), 'cannot rename dir over file' );
    is( $! + 0, ENOTDIR, 'errno is ENOTDIR' );
}

note "-------------- rename: file to self is no-op (POSIX) --------------";
{
    my $file = Test::MockFile->file( '/mock/self', 'precious data' );

    ok( rename( '/mock/self', '/mock/self' ), 'rename to self returns true' );
    is( $file->contents, 'precious data', 'file contents preserved after rename to self' );
    ok( $file->exists, 'file still exists after rename to self' );
}

note "-------------- rename: directory to self is no-op (POSIX) --------------";
{
    my $dir = Test::MockFile->new_dir('/mock/selfdir');

    ok( rename( '/mock/selfdir', '/mock/selfdir' ), 'rename dir to self returns true' );
    ok( $dir->exists, 'directory still exists after rename to self' );
}

note "-------------- rename: symlink to self is no-op (POSIX) --------------";
{
    my $target = Test::MockFile->file( '/mock/selflink_target', 'data' );
    my $link   = Test::MockFile->symlink( '/mock/selflink_target', '/mock/selflink' );

    ok( rename( '/mock/selflink', '/mock/selflink' ), 'rename symlink to self returns true' );
    ok( $link->is_link, 'symlink still a link after rename to self' );
    is( readlink('/mock/selflink'), '/mock/selflink_target', 'symlink target preserved after rename to self' );
}

done_testing();
