#!/usr/bin/perl -w

# Test for GitHub issue #179: "Spooky action-at-a-distance"
#
# File check operators (-S, -f, etc.) on real (unmocked) filehandles should
# not retain references that prevent garbage collection. A leaked reference
# to a socket filehandle can keep the fd open, causing reads on the other
# end of a socketpair to hang waiting for EOF.
#
# Root cause: $_last_call_for in Overload::FileCheck stored filehandle refs.
# Fix: Only cache string filenames, not refs.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;

use Scalar::Util qw(weaken);
use Socket;

use Test::MockFile qw< nostrict >;

# Probe: check if Overload::FileCheck has the ref leak fix.
# Without it (O::FC PR #25), $_last_call_for retains fh refs.
my $ofc_has_fix;
{
    my $probe;
    {
        open my $fh, '<', '/dev/null' or die "Cannot open /dev/null: $!";
        $probe = $fh;
        Scalar::Util::weaken($probe);
        no warnings;
        -f $fh;
    }
    $ofc_has_fix = !defined $probe;
}

# Test 1: Filehandle passed to -f is not retained
SKIP: {
    skip "Overload::FileCheck does not have ref leak fix (PR #25)", 1 unless $ofc_has_fix;
    my $weak_ref;

    {
        open my $fh, '<', '/dev/null' or die "Cannot open /dev/null: $!";
        $weak_ref = $fh;
        weaken($weak_ref);

        ok( defined $weak_ref, "weak ref is defined before scope exit" );

        no warnings;
        -f $fh;
    }

    ok( !defined $weak_ref, "filehandle is garbage collected after -f (GH #179)" );
}

# Test 2: Socket filehandle passed to -S is not retained
SKIP: {
    skip "Overload::FileCheck does not have ref leak fix (PR #25)", 1 unless $ofc_has_fix;
    my $weak_ref;

    {
        open my $fh, '<', '/dev/null' or die "Cannot open /dev/null: $!";
        $weak_ref = $fh;
        weaken($weak_ref);

        no warnings;
        -S $fh;
    }

    ok( !defined $weak_ref, "filehandle is garbage collected after -S (GH #179)" );
}

# Test 3: The exact scenario from GH #179 — socketpair with dup'd fd
# This would hang without the fix because the dup'd write handle stays open.
SKIP: {
    skip "Overload::FileCheck does not have ref leak fix (PR #25)", 1 unless $ofc_has_fix;
    skip "socketpair not available", 1 unless eval { socketpair my $a, my $b, AF_UNIX, SOCK_STREAM, 0; 1 };

    my $pid = fork();
    if ( !defined $pid ) {
        skip "fork not available", 1;
    }

    if ( $pid == 0 ) {
        # Child: reproduce the bug scenario with a timeout
        $SIG{ALRM} = sub { exit 1 };    # exit 1 = hung (bug present)
        alarm(5);

        socketpair my $r, my $w, AF_UNIX, SOCK_STREAM, 0
            or exit 2;

        my $fd = fileno $w;
        do {
            open my $w2, "<&=", $fd;
            -S $w2;
        };

        close $w;
        my $line = <$r>;    # Should get EOF immediately if $w2 was freed
        exit 0;             # exit 0 = success (no hang)
    }

    waitpid $pid, 0;
    my $exit = $? >> 8;

    is( $exit, 0, "socketpair read does not hang after -S on dup'd filehandle (GH #179)" );
}

done_testing;
