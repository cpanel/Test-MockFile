#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception qw< dies >;
use Test::MockFile;

my $euid = $>;
my $egid = int $);
my $filename = __FILE__;
my $file     = Test::MockFile->file( $filename, 'whatevs' );

subtest( 'Unmocked files and mixing unmocked and mocked files' => sub {
    like(
        dies( sub { chown -1, -1, $filename, '/foo_DOES_NOT_EXIST.znxc' } ),
        qr/^\QYou called chown() on a mix of mocked and unmocked files\E/xms,
        'Even without strict mode, you cannot mix mocked and unmocked files (chown)',
    );

    like(
        dies( sub { chmod 0755, $filename, '/foo_DOES_NOT_EXIST.znxc' } ),
        qr/^\QYou called chmod() on a mix of mocked and unmocked files\E/xms,
        'Even without strict mode, you cannot mix mocked and unmocked files (chmod)',
    );
});

done_testing();
exit;
