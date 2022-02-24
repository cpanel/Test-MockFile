#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Errno qw/ENOENT/;

use Test::MockFile qw< nostrict >;    # Everything below this can have its open overridden.

{
    my $path = '/foo';
    my $mock = Test::MockFile->file($path);
    is(mkdir($path), 1, "can mkdir on a nonexisting file mock");
    ok(-d $path, "$path is now a dir");
    ok($mock->is_dir, "$path is is_dir");
    is(rmdir($path), 1, "rmdir $path");
    is($mock->{'mode'}, 0, "mode is cleared on rmdir");

    open(my $fh, '>', $path) or die("$!");
    print {$fh} "content\n";
    close $fh;

    ok(-f $path, "$path is now a file");
    ok($mock->is_file, "$path is is_file");
    unlink $path;
    is($mock->{'mode'}, 0, "mode is cleared on unlink");
}

{
    my $path = '/foo_dir';
    my $mock = Test::MockFile->dir($path);

    open(my $fh, '>', $path) or die("$!");
    print {$fh} "content\n";
    close $fh;

    ok(-f $path, "$path is now a file");
    ok($mock->is_file, "$path is is_file");
    unlink $path;
    is($mock->{'mode'}, 0, "mode is cleared on unlink");

    is(mkdir($path), 1, "can mkdir on a nonexisting file mock");
    ok(-d $path, "$path is now a dir");
    ok($mock->is_dir, "$path is is_dir");
    is(rmdir($path), 1, "rmdir $path");
    is($mock->{'mode'}, 0, "mode is cleared on rmdir");
}



done_testing();
exit;
