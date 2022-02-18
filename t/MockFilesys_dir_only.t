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

my $temp_dir = tempdir( CLEANUP => 1 );
my ( undef, $filename ) = tempfile( DIR => $temp_dir );


done_testing();
exit;
