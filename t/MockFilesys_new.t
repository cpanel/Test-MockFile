#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use File::Temp qw/tempfile tempdir/;
use File::Basename;

#use Errno qw/ENOENT EBADF/;

use Test::MockFileSys;    # Everything below this can have its open overridden.

# Grabs existing objects?
#my $fs = Test::MockFileSys->new; # Singleton Only one at a time.

my $old_object;
{
    my $mock1 = Test::MockFileSys->new();
    my $mock2 = Test::MockFileSys->new();

    isa_ok( $mock1, ['Test::MockFileSys'], "First call to new gives us a mock file system" );
    isa_ok( $mock2, ['Test::MockFileSys'], "A Second call to new gives us a mock file system" );
    is( "$mock1", "$mock2", "Any further calls give us the same object." );

    $old_object = "$mock1";
}

my $new_mock = Test::MockFileSys->new();
isnt( "$new_mock", $old_object, "The singleton gets destroyed when its last ref goes out of scope and so a new call gives us a new object." );

done_testing();
exit;
