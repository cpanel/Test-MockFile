# Copyright (c) 2018, cPanel, LLC.
# All rights reserved.
# http://cpanel.net
#
# This is free software; you can redistribute it and/or modify it under the
# same terms as Perl itself. See L<perlartistic>.

package Test::MockFile;

use strict;
use warnings;

use IO::File                   ();
use Symbol                     ();
use Test::MockFile::Stat       ();
use Test::MockFile::FileHandle ();
use Scalar::Util               ();

=head1 NAME

Test::MockFile - Lets tests validate code which interacts with files without them 

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';

our %files_being_mocked;
our $strict_mode = 0;

BEGIN {
    *CORE::GLOBAL::open = sub : prototype(*;$@) {
        if ($strict_mode) {
            scalar @_ == 3 or die;
            defined $files_being_mocked{ $_[2] } or die;
        }
        goto \&CORE::open if scalar @_ != 3;
        goto \&CORE::open unless defined $files_being_mocked{ $_[2] };

        #
        my $mock_file = $files_being_mocked{ $_[2] };
        my $mode      = $_[1];

        # If contents is undef, we act like the file isn't there.
        if ( $mode eq '<' && !defined $mock_file->{'contents'} ) {
            $! = "No such file or directory";
            return;
        }

        $_[0] = IO::File->new;
        tie *{ $_[0] }, 'Test::MockFile::FileHandle', $_[1], $_[2];

        # This is how we tell if the file is open by something.

        $mock_file->{'fh'} = $_[0];
        Scalar::Util::weaken( $mock_file->{'fh'} );    # Will this make it go out of scope?

        return 1;
    };
}

=head1 SYNOPSIS

Intercepts file system calls for specific files so unit testing can take place without any files being altered on disk.

Perhaps a little code snippet.

    use Test::MockFile;

    my $foo = Test::MockFile->file("/foo/bar", "contents\ngo\nhere");
    open(my $fh, "<", "/foo/bar") or die; # Does not actually open the file on disk.
    close $fh;

    my $baz = Test::MockFile->file("/foo/baz"); # File starts out missing.
    my $opened = open(my $baz_fh, "<", "/foo/baz"); # File reports as missing so fails.

    open($baz_fh, ">", "/foo/baz") or die; # open for writing
    print <$baz_fh> "replace contents\n";
    
    open($baz_fh, ">>", "/foo/baz") or die; # open for append.
    print <$baz_fh> "second line";
    close $baz_fh;
    
    print $baz->contents;

=head1 EXPORT

No exports are provided by this module.

=head1 SUBROUTINES/METHODS

=head2 file

Args: ($file, $contents, $stats)

This will mock a file and intercept all calls related to the file you pass to this method.

=cut

sub file {
    my ( $class, $file, $contents, $stats ) = @_;
    $file or die("No file provided to instantiate $class");

    $files_being_mocked{$file} and die("It looks like $file is already being mocked. We don't support double mocking yet.");

    my $self = bless { 'file' => $file }, $class;
    $files_being_mocked{$file}->{'contents'}  = $contents;
    $files_being_mocked{$file}->{'info'}      = $stats;
    $files_being_mocked{$file}->{'mocked_by'} = "$self";

    return $self;
}

sub DESTROY {
    my ($self) = @_;
    $self or return;
    ref $self or return;
    my $file = $self->{'file'} or return;

    $files_being_mocked{$file}->{'mocked_by'} eq "$self" or return;
    delete $files_being_mocked{$file};
}

=head2 contents

Reports the current contents of the file.

=cut

sub contents {
    my ($self) = @_;
    $self or return;

    return $files_being_mocked{ $self->{'file'} }->{'contents'};
}

=head1 AUTHOR

Todd Rinaldo, C<< <toddr at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to L<https://github.com/CpanelInc/Test-MockFile>. 

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::MockFile


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-MockFile>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Test-MockFile>

=item * Search CPAN

L<https://metacpan.org/release/Test-MockFile>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2018 Todd Rinaldo.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1;    # End of Test::MockFile
