#!/usr/bin/perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockFileSys qw/strict/;


my $files_mocked = \%Test::MockFile::files_being_mocked;

#$fs->mkdir( '/foo', 0755); # Auto mocks in strict mode.
{
    note 'basic dir';
    my $fs = Test::MockFileSys->new;

    ok ( !-d  '/foo', "/foo isn't there");
    my $mocked_foo = $files_mocked->{'/foo'};
    
    isa_ok($mocked_foo, ['Test::MockFile'], "-d triggered a new Mocked file");
    is($fs->dir('/foo'), $mocked_foo, "And a latter call to dir grabs the same object");
    
    is($fs->mkdir('/foo', 0700), $mocked_foo, "mkdir gives back the now existing dir as the same object");
    my @stat = stat('/foo');
    is($stat[2] & 0777, 0700, "Perms on the dir are right");
    
    ## unmock the thing.
    # NOTE: it will not unmock if something is also holding the object.
    #$fs->unmock('/foo/bar');
    $fs->unmock('/foo');
    is($fs->{'files'}, {}, "unmock clears the item from the list");
}

{
    note "Basic file";
    my $file_name = "/foo/bar";
    my $fs = Test::MockFileSys->new;

    $fs->write_file($file_name, "abc\ndef\n", { perms => 0644 } );

    open(my $fh, '<', $file_name) or die("$! ($file_name)");
    is(<$fh>, "abc\n", "Line 1 of the file");
    is(<$fh>, "def\n", "Line 2 of the file");
    close $fh;
    
    is $fs->file_contents($file_name), "abc\ndef\n", "\$fs->file_contents";
    
    my @stat = stat($file_name);
    is($stat[2] & 0644, 0644, "Perms on the file are right");
    
}

{
    note "automock in strict mode";
    
    my $fs = Test::MockFileSys->new;

    mkdir '/foo/bar';

    my $file_name = '/foo/bar/baz';
    open(my $fh, '>', $file_name) or die("$!");
    print {$fh} 'yabba dabba doo!';
    close $fh;
    
    is($fs->file_contents($file_name), 'yabba dabba doo!', "file is automocked and accessible from \$fs");
    
    unlink $file_name;
    ok( !-e $file_name, "$file_name is now missing");
    mkdir $file_name;
    ok( -d $file_name, "$file_name is now a directory not a file");
}

done_testing();
exit;
