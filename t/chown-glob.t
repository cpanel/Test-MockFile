#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception qw< lives dies >;
use if $ENV{'MOCKED'}, 'Test::MockFile';

my $euid     = $>;
my $egid     = int $);
my $filename = '/tmp/not-a-file';
my $file     = Test::MockFile->file($filename) if $ENV{'MOCKED'};

open( my $fh, '>', $filename ) or die;
print {$fh} "whatevs\n";
is( chown( $euid + 9999, $egid + 9999, $fh ), 1, "chown on a file handle works" );
close $fh;

my (
    $dev,   $ino,   $mode,  $nlink,   $uid, $gid, $rdev, $size,
    $atime, $mtime, $ctime, $blksize, $blocks
) = stat($filename);
is( $uid, $euid + 9999, "Owner of the file is now there" );
is( $gid, $egid + 9999, "Group of the file is now there" );

unlink $filename;
done_testing();
exit;
