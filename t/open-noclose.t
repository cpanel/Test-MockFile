#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockFile qw< nostrict >;

{
    like(
        dies { myread() },
        qr/Missing file argument/,
        'missing file argument'
    );

    my $path      = q[/tmp/somewhere];
    my $mock_file = Test::MockFile->file($path);
    like(
        dies { myread($path) },
        qr/Failed to open file/,
        'missing file'
    );

    $mock_file->touch;

    note "empty file";
    my $contents = myread($path);
    is( $contents, [], "empty file" ) or diag explain $contents;

    my $test_contents = <<'EOS';
Some content
for your eyes only
EOS

    $mock_file->contents($test_contents);

    is( -z $path, undef, "-z says file is now not empty" );

    is( $mock_file->contents, $test_contents, "File is populated" );

    my $out = myread($path);
    is $out, [ split( /\n/, $mock_file->contents ) ], "$path file should not be empty (on second read)"
      or diag explain $out;

}

done_testing;

sub myread {
    my ($script) = @_;

    die q[Missing file argument] unless defined $script;

    my @lines;
    my $fh;

    #diag explain \%Test::MockFile::files_being_mocked;
    open( $fh, '<', $script ) or die qq[Failed to open file: $!];

    while ( my $line = readline $fh ) {
        chomp $line;
        push @lines, $line;
    }

    return \@lines;
}

1;
