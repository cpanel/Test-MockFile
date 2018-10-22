# Copyright (c) 2018, cPanel, LLC.
# All rights reserved.
# http://cpanel.net
#
# This is free software; you can redistribute it and/or modify it under the
# same terms as Perl itself. See L<perlartistic>.

package Test::MockFile;

use strict;
use warnings;

# perl -MFcntl -E'eval "say q{$_: } . $_" foreach sort {eval "$a" <=> eval "$b"} qw/O_RDONLY O_WRONLY O_RDWR O_CREAT O_EXCL O_NOCTTY O_TRUNC O_APPEND O_NONBLOCK O_NDELAY O_EXLOCK O_SHLOCK O_DIRECTORY O_NOFOLLOW O_SYNC O_BINARY O_LARGEFILE/'
use Fcntl;    # O_RDONLY, etc.

use Cwd                        ();
use IO::File                   ();
use Test::MockFile::FileHandle ();
use Test::MockFile::DirHandle  ();
use Scalar::Util               ();

use Errno qw/ENOENT ELOOP EEXIST/;

#use Overload::FileCheck ('from_stat' => \&_mock_stat);

use constant FOLLOW_LINK_MAX_DEPTH => 10;

=head1 NAME

Test::MockFile - Lets tests validate code which interacts with files without them 

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';

our %files_being_mocked;
our $strict_mode = 0;

# From http://man7.org/linux/man-pages/man7/inode.7.html
use constant S_IFMT    => 0170000;    # bit mask for the file type bit field
use constant S_IFPERMS => 07777;      # bit mask for file perms.

use constant S_IFSOCK => 0140000;     # socket
use constant S_IFLNK  => 0120000;     # symbolic link
use constant S_IFREG  => 0100000;     # regular file
use constant S_IFBLK  => 0060000;     # block device
use constant S_IFDIR  => 0040000;     # directory
use constant S_IFCHR  => 0020000;     # character device
use constant S_IFIFO  => 0010000;     # FIFO

BEGIN {
    *CORE::GLOBAL::open = sub : prototype(*;$@) {
        my $abs_path = _abs_path_to_file( $_[2] );

        if ($strict_mode) {
            scalar @_ == 3 or die;
            defined $files_being_mocked{$abs_path} or die("Unexpected open of $_[2] in strict Test::MockFile strict mode");
        }

        # open(my $fh, ">filehere"); # Just don't do this. It's bad.
        goto \&CORE::open if scalar @_ != 3;

        my $mode = $_[1];

        # TODO: We technically need to support this.
        # open(my $fh, "-|", "/bin/hostname"); # Read from command
        # open(my $fh, "|-", "/bin/passwd"); # Write to command
        goto \&CORE::open if ( $mode eq '|-' || $mode eq '-|' );

        # These are the only modes we support right now.
        goto \&CORE::open unless grep { $_ eq $mode } qw/> < >> +< +> +>>/;

        goto \&CORE::open unless defined $files_being_mocked{$abs_path};

        #
        my $mock_file = $files_being_mocked{$abs_path};

        # If contents is undef, we act like the file isn't there.
        if ( !defined $mock_file->{'contents'} && grep { $mode eq $_ } qw/< +</ ) {
            $! = ENOENT;
            return;
        }

        my $rw = '';
        $rw .= 'r' if grep { $_ eq $mode } qw/+< +> +>> </;
        $rw .= 'w' if grep { $_ eq $mode } qw/+< +> +>> > >>/;

        $_[0] = IO::File->new;
        tie *{ $_[0] }, 'Test::MockFile::FileHandle', $abs_path, $rw;

        # This is how we tell if the file is open by something.

        $files_being_mocked{$abs_path}->{'fh'} = $_[0];
        Scalar::Util::weaken( $_[0] );    # Will this make it go out of scope?

        # Fix tell based on open options.
        if ( $mode eq '>>' or $mode eq '+>>' ) {
            $files_being_mocked{$abs_path}->{'contents'} //= '';
            seek $_[0], length( $files_being_mocked{$abs_path}->{'contents'} ), 0;
        }
        elsif ( $mode eq '>' or $mode eq '+>' ) {
            $files_being_mocked{$abs_path}->{'contents'} = '';
        }

        return 1;
    };

    # sysopen FILEHANDLE, FILENAME, MODE, MASK
    # sysopen FILEHANDLE, FILENAME, MODE

    # We curently support:
    # 1 - O_RDONLY - Read only.
    # 2 - O_WRONLY - Write only.
    # 3 - O_RDWR - Read and write.

    # 6 - O_APPEND - Append to the file.
    # 7 - O_TRUNC - Truncate the file.

    # 5 - O_EXCL - Fail if the file already exists.
    # 4 - O_CREAT - Create the file if it doesn't exist.
    # 8 - O_NOFOLLOW - Fail if the last path component is a symbolic link.

    *CORE::GLOBAL::sysopen = sub : prototype(*$$;$) {
        my $abs_path = _abs_path_to_file( $_[1] );

        if ($strict_mode) {
            defined $files_being_mocked{$abs_path} or die("Unexpected sysopen of $_[1] in strict Test::MockFile strict mode");
        }

        goto \&CORE::sysopen unless defined $files_being_mocked{$abs_path};

        my $mock_file    = $files_being_mocked{$abs_path};
        my $sysopen_mode = $_[2];

        if ( $sysopen_mode & ( O_NDELAY | O_SYNC | O_EXLOCK | O_SHLOCK | O_DIRECTORY | O_BINARY | O_LARGEFILE | O_NOCTTY | O_NONBLOCK ) ) {
            die( sprintf( "Sorry, can't open %s with 0x%x permissions. Some of your permissions are not yet supported by %s", $_[1], $sysopen_mode, __PACKAGE__ ) );
        }

        # O_NOFOLLOW
        if ( ( $sysopen_mode & O_NOFOLLOW ) == O_NOFOLLOW && $mock_file->is_link ) {
            $! = 40;
            return undef;
        }

        # O_EXCL
        if ( $sysopen_mode & O_EXCL && $sysopen_mode & O_CREAT && defined $mock_file->{'contents'} ) {
            $! = EEXIST;
            return;
        }

        # O_CREAT
        if ( $sysopen_mode & O_CREAT && !defined $mock_file->{'contents'} ) {
            $mock_file->{'contents'} = '';
        }

        # O_TRUNC
        if ( $sysopen_mode & O_TRUNC && defined $mock_file->{'contents'} ) {
            $mock_file->{'contents'} = '';

        }

        my $rd_wr_mode = $sysopen_mode & 3;
        my $rw =
            $rd_wr_mode == O_RDONLY ? 'r'
          : $rd_wr_mode == O_WRONLY ? 'w'
          : $rd_wr_mode == O_RDWR   ? 'rw'
          :                           die("Unexpected sysopen read/write mode ($rd_wr_mode)");    # O_WRONLY| O_RDWR mode makes no sense and we should die.

        # If contents is undef, we act like the file isn't there.
        if ( !defined $mock_file->{'contents'} && $rd_wr_mode == O_RDONLY ) {
            $! = ENOENT;
            return;
        }

        $_[0] = IO::File->new;
        tie *{ $_[0] }, 'Test::MockFile::FileHandle', $abs_path, $rw;

        # This is how we tell if the file is open by something.
        $files_being_mocked{$abs_path}->{'fh'} = $_[0];
        Scalar::Util::weaken( $_[0] );    # Will this make it go out of scope?

        # O_TRUNC
        if ( $sysopen_mode & O_TRUNC ) {
            $mock_file->{'contents'} = '';
        }

        # O_APPEND
        if ( $sysopen_mode & O_APPEND ) {
            $_[0]->{'tell'} = length( $mock_file->{'contents'} );
        }

        return 1;
    };

    *CORE::GLOBAL::opendir = sub : prototype(*$) {

        my $abs_path = _abs_path_to_file( $_[1] );
        if ($strict_mode) {
            scalar @_ == 2 or die;
            defined $files_being_mocked{$abs_path} or die;
        }

        goto \&CORE::opendir if scalar @_ != 2;
        goto \&CORE::opendir unless defined $files_being_mocked{$abs_path};

        my $mock_dir = $files_being_mocked{$abs_path};
        if ( !defined $mock_dir->{'contents'} ) {
            $! = ENOENT;
            return undef;
        }

        # This isn't a real IO::Dir.
        $_[0] = Test::MockFile::DirHandle->new( $abs_path, $mock_dir->{'contents'} );

        # This is how we tell if the file is open by something.
        $files_being_mocked{$abs_path}->{'fh'} = $_[0];
        Scalar::Util::weaken( $_[0] );    # Will this make it go out of scope?

        return 1;

    };

    *CORE::GLOBAL::readdir = sub : prototype(*) {
        my ($self) = @_;

        goto \&CORE::readdir if !ref $self || ref $self ne 'Test::MockFile::DirHandle';
        goto \&CORE::readdir unless defined $files_being_mocked{ $self->{'dir'} };

        if ( !defined $self->{'files_in_readdir'} ) {
            die("Did a readdir on an empty dir. This shouldn't have been able to have been opened!");
        }

        if ( !defined $self->{'tell'} ) {
            die("readdir called on a closed dirhandle");
        }

        # At EOF for the dir handle.
        return undef if $self->{'tell'} > $#{ $self->{'files_in_readdir'} };

        if (wantarray) {
            my @return;
            foreach my $pos ( $self->{'tell'} .. $#{ $self->{'files_in_readdir'} } ) {
                push @return, $self->{'files_in_readdir'}->[$pos];
            }
            $self->{'tell'} = $#{ $self->{'files_in_readdir'} } + 1;
            return @return;
        }

        return $self->{'files_in_readdir'}->[ $self->{'tell'}++ ];
    };

    *CORE::GLOBAL::telldir = sub : prototype(*) {
        my ($self) = @_;

        goto \&CORE::telldir if !ref $self || ref $self ne 'Test::MockFile::DirHandle';
        goto \&CORE::telldir unless defined $files_being_mocked{ $self->{'dir'} };

        if ( !defined $self->{'files_in_readdir'} ) {
            die("Did a telldir on an empty dir. This shouldn't have been able to have been opened!");
        }

        if ( !defined $self->{'tell'} ) {
            die("telldir called on a closed dirhandle");
        }

        return $self->{'tell'};
    };

    *CORE::GLOBAL::rewinddir = sub : prototype(*) {
        my ($self) = @_;

        goto \&CORE::rewinddir if !ref $self || ref $self ne 'Test::MockFile::DirHandle';
        goto \&CORE::rewinddir unless defined $files_being_mocked{ $self->{'dir'} };

        if ( !defined $self->{'files_in_readdir'} ) {
            die("Did a rewinddir on an empty dir. This shouldn't have been able to have been opened!");
        }

        if ( !defined $self->{'tell'} ) {
            die("rewinddir called on a closed dirhandle");
        }

        $self->{'tell'} = 0;
        return 1;
    };

    *CORE::GLOBAL::seekdir = sub : prototype(*$) {
        my ( $self, $goto ) = @_;

        goto \&CORE::seekdir if !ref $self || ref $self ne 'Test::MockFile::DirHandle';
        goto \&CORE::seekdir unless defined $files_being_mocked{ $self->{'dir'} };

        if ( !defined $self->{'files_in_readdir'} ) {
            die("Did a seekdir on an empty dir. This shouldn't have been able to have been opened!");
        }

        if ( !defined $self->{'tell'} ) {
            die("seekdir called on a closed dirhandle");
        }

        return $self->{'tell'} = $goto;
    };

    *CORE::GLOBAL::closedir = sub : prototype(*) {
        my ($self) = @_;

        goto \&CORE::closedir if !ref $self || ref $self ne 'Test::MockFile::DirHandle';
        goto \&CORE::closedir unless defined $files_being_mocked{ $self->{'dir'} };

        if ( !defined $self->{'files_in_readdir'} ) {
            die("Did a closedir on an empty dir. This shouldn't have been able to have been opened!");
        }

        # Already closed?
        return if !defined $self->{'tell'};

        delete $self->{'tell'};
        return 1;
    };
}

sub _mode_can_write {
    my ($mode) = @_;
    return ( $mode eq '<' ) ? 0 : 1;
}

sub _mode_can_read {
    my ($mode) = @_;
    return ( $mode eq '>' or $mode eq '>>' ) ? 0 : 1;
}

#Overload::FileCheck::mock_stat(\&mock_stat);
sub _mock_stat {
    my ( $file_or_fh, $follow_link ) = @_;

    if ( scalar @_ != 1 ) {
        return -1;
    }

    if ( !length $file_or_fh ) {
        return -1;
    }

    my $file = _find_file_or_fh( $file_or_fh, $follow_link );
    return $file if ref $file eq 'ARRAY';    # Allow an ELOOP to fall through here.
    return -1 unless length $file;

    my $file_data = $files_being_mocked{$file};
    return -1 unless $file_data;

    # File is not present so no stats for you!
    return [] if !defined $file_data->{'contents'};

    # Make sure the file size is correct in the stats before returning its contents.
    return [ $file_data->stat ];
}

sub _fh_to_file {
    my ($fh) = @_;

    # Return if it's a string. Nothing to do here!
    return $fh unless ref $fh;

    foreach my $file_name ( keys %files_being_mocked ) {
        my $mock_fh = $files_being_mocked{$file_name}->{'fh'};
        next unless $mock_fh;              # File isn't open.
        next unless "$mock_fh" eq "$fh";

        return $file_name;
    }

    return;
}

sub _find_file_or_fh {
    my ( $file_or_fh, $follow_link, $depth, $parent ) = @_;

    if ( $follow_link and !defined $depth ) {
        $depth = 0;
    }

    my $file = _fh_to_file($file_or_fh);
    return $file unless $follow_link;

    if ( $parent and !$files_being_mocked{$file} ) {
        die("Mocked file $parent points to unmocked file $file");
    }

    return $file unless $files_being_mocked{$file}->is_link;

    $depth ||= 0;
    $depth++;

    #Protect against circular loops.
    if ( $depth > FOLLOW_LINK_MAX_DEPTH ) {
        $! = ELOOP;
        return [];
    }

    return _find_file_or_fh( $files_being_mocked{$file}->readlink, 1, $depth, $file );
}

sub _abs_path_to_file {
    my ($path) = shift;

    defined $path or return;
    return $path if $path =~ m{^/};

    return Cwd::getcwd() . "/$path";
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

sub new {
    my $class = shift @_;

    my %opts;
    if ( scalar @_ == 1 && ref $_[0] ) {
        %opts = %{ $_[0] };
    }
    elsif ( scalar @_ % 2 ) {
        die sprintf( "Unknown args (%d) passed to new", scalar @_ );
    }
    else {
        %opts = @_;
    }

    my $file_name = $opts{'file_name'} or die("Mock file created without a file name!");

    if ( $file_name !~ m{^/} ) {
        $file_name = $opts{'file_name'} = _abs_path_to_file($file_name);
    }

    my $now = time;

    my $self = bless {
        'dev'       => 0,        # stat[0]
        'inode'     => 0,        # stat[1]
        'mode'      => 0,        # stat[2]
        'nlink'     => 0,        # stat[3]
        'uid'       => 0,        # stat[4]
        'gid'       => 0,        # stat[5]
        'rdev'      => 0,        # stat[6]
                                 # 'size'     => undef,    # stat[7] -- Method call
        'atime'     => $now,     # stat[8]
        'mtime'     => $now,     # stat[9]
        'ctime'     => $now,     # stat[10]
        'blksize'   => 4096,     # stat[11]
                                 # 'blocks'   => 0,        # stat[12] -- Method call
        'fileno'    => undef,    # fileno()
        'tty'       => 0,        # possibly this is already provided in mode?
        'readlink'  => '',       # what the symlink points to.
        'file_name' => undef,
        'contents'  => undef,
    }, $class;

    foreach my $key ( keys %opts ) {

        # Ignore Stuff that's not a valid key for this class.
        next unless exists $self->{$key};

        # If it's passed in, we override them.
        $self->{$key} = $opts{$key};
    }

    $self->{'fileno'} //= _unused_fileno();

    $files_being_mocked{$file_name} = $self;

    Scalar::Util::weaken( $files_being_mocked{$file_name} );

    return $self;
}

sub file {
    my ( $class, $file, $contents, @stats ) = @_;

    length $file or die("No file provided to instantiate $class");
    $files_being_mocked{$file} and die("It looks like $file is already being mocked. We don't support double mocking yet.");

    my %stats;
    if ( scalar @stats == 1 ) {
        %stats = %{ $stats[0] };
    }
    elsif ( scalar @stats % 2 ) {
        die sprintf( "Unknown args (%d) passed to file", scalar @_ );
    }
    else {
        %stats = @stats;
    }

    my $perms = defined $stats{'mode'} ? int( $stats{'mode'} ) : 0666;
    $stats{'mode'} = ( $perms ^ umask ) & S_IFREG;

    return $class->new(
        {
            'file_name' => $file,
            'contents'  => $contents,
            %stats
        }
    );
}

# NOTE: We don't directly support taking stats when instantiating.
sub symlink {
    my ( $class, $file, $readlink ) = @_;

    length $file     or die("No file provided to instantiate $class");
    length $readlink or die("No file provided for $file to point to in $class");

    $files_being_mocked{$file} and die("It looks like $file is already being mocked. We don't support double mocking yet.");

    return $class->new(
        {
            'file_name' => $file,
            'contents'  => undef,
            'readlink'  => $readlink,
            'mode'      => 0777 | S_IFLNK,
        }
    );
}

sub dir {
    my ( $class, $dir_name, $contents, @stats ) = @_;

    length $dir_name or die("No directory name provided to instantiate $class");
    $files_being_mocked{$dir_name} and die("It looks like $dir_name is already being mocked. We don't support double mocking yet.");

    # Because undef means it's a missing dir.
    if ( defined $contents ) {
        $contents ||= [qw/. ../];
        ref $contents eq 'ARRAY' or die("directory contents must be an array ref or undef.");
    }

    my %stats;
    if ( scalar @stats == 1 ) {
        %stats = %{ $stats[0] };
    }
    elsif ( scalar @stats % 2 ) {
        die sprintf( "Unknown args (%d) passed to file", scalar @_ );
    }
    else {
        %stats = @stats;
    }

    my $perms = defined $stats{'mode'} ? int( $stats{'mode'} ) : 0666;
    $stats{'mode'} = ( $perms ^ umask ) & S_IFDIR;

    return $class->new(
        {
            'file_name' => $dir_name,
            'contents'  => $contents,
            %stats
        }
    );
}

sub DESTROY {
    my ($self) = @_;
    $self or return;
    ref $self or return;

    my $file_name = $self->{'file_name'} or return;

    $self == $files_being_mocked{$file_name} or die("Tried to destroy object for $file_name ($self) but something else is mocking it?");
    delete $files_being_mocked{$file_name};
}

=head2 contents

Reports or updates the current contents of the file.

=cut

sub contents {
    my ($self) = @_;
    $self or die;

    # If 2nd arg was passed.
    if ( scalar @_ == 2 ) {
        return $self->{'contents'} = $_[1];
    }

    return $self->{'contents'};
}

sub stat {
    my $self = shift;

    return (
        $self->{'dev'},        # stat[0]
        $self->{'inode'},      # stat[1]
        $self->{'mode'},       # stat[2]
        $self->{'nlink'},      # stat[3]
        $self->{'uid'},        # stat[4]
        $self->{'gid'},        # stat[5]
        $self->{'rdev'},       # stat[6]
        $self->size,           # stat[7]
        $self->{'atime'},      # stat[8]
        $self->{'mtime'},      # stat[9]
        $self->{'ctime'},      # stat[10]
        $self->{'blksize'},    # stat[11]
        $self->blocks,         # stat[12]
    );
}

sub _unused_fileno {
    return 900;                # TODO
}

sub readlink {
    my ($self) = @_;

    return $self->{'readlink'};
}

sub is_link {
    my ($self) = @_;

    return ( length $self->{'readlink'} && $self->{'mode'} & S_IFLNK ) ? 1 : 0;
}

sub size {
    my ($self) = @_;

    return length $self->contents;
}

sub blocks {
    my ($self) = @_;

    return $self->size / abs( $self->{'blksize'} || 1 );
}

sub chmod {
    my ( $self, $mode ) = @_;

    $mode = int($mode) | S_IFPERMS;

    $self->{'mode'} = ( $self->{'mode'} & S_IFMT ) + $mode;

    return $mode;
}

sub mtime {
    my ( $self, $time ) = @_;

    if ( @_ == 2 && defined $time && $time =~ m/^[0-9]+$/ ) {
        $self->{'mtime'} = $time;
    }

    return $self->{'mtime'};
}

sub ctime {
    my ( $self, $time ) = @_;

    if ( @_ == 2 && defined $time && $time =~ m/^[0-9]+$/ ) {
        $self->{'ctime'} = $time;
    }

    return $self->{'ctime'};
}

sub atime {
    my ( $self, $time ) = @_;

    if ( @_ == 2 && defined $time && $time =~ m/^[0-9]+$/ ) {
        $self->{'atime'} = $time;
    }

    return $self->{'atime'};
}

1;

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
