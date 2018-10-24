# Copyright (c) 2018, cPanel, LLC.
# All rights reserved.
# http://cpanel.net
#
# This is free software; you can redistribute it and/or modify it under the
# same terms as Perl itself. See L<perlartistic>.

package Test::MockFile::Stat;

use strict;
use warnings;

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

sub new {
    my $class = shift @_;

    my %opts;
    if ( scalar @_ == 1 ) {
        %opts = %{ $_[0] };
    }
    else {
        %opts = @_;
    }

    my $now = time;

    my $self = bless {
        'dev'      => 0,        # stat[0]
        'inode'    => 0,        # stat[1]
        'mode'     => 0,        # stat[2]
        'nlink'    => 0,        # stat[3]
        'uid'      => 0,        # stat[4]
        'gid'      => 0,        # stat[5]
        'rdev'     => 0,        # stat[6]
        'size'     => undef,    # stat[7]
        'atime'    => $now,     # stat[8]
        'mtime'    => $now,     # stat[9]
        'ctime'    => $now,     # stat[10]
        'blksize'  => 4096,     # stat[11]
        'blocks'   => 0,        # stat[12]
        'fileno'   => undef,    # fileno()
        'tty'      => 0,        # possibly this is already provided in mode?
        'readlink' => '',       # what the symlink points to.
    }, $class;

    foreach my $key ( keys %opts ) {

        # Ignore Stuff that's not a valid key for this class.
        next unless exists $self->{$key};

        # If it's passed in, we override them.
        $self->{$key} = $opts{$key};
    }

    $self->{'fileno'} //= _unused_fileno();

    if ( $self->{'size'} && !$self->{'blocks'} ) {
        $self->resize;
    }

    return $self;
}

sub get_stats {
    my $self = shift;

    return (
        $self->{'dev'},        # stat[0]
        $self->{'inode'},      # stat[1]
        $self->{'mode'},       # stat[2]
        $self->{'nlink'},      # stat[3]
        $self->{'uid'},        # stat[4]
        $self->{'gid'},        # stat[5]
        $self->{'rdev'},       # stat[6]
        $self->{'size'},       # stat[7]
        $self->{'atime'},      # stat[8]
        $self->{'mtime'},      # stat[9]
        $self->{'ctime'},      # stat[10]
        $self->{'blksize'},    # stat[11]
        $self->{'blocks'},     # stat[12]
    );
}

sub _unused_fileno {
    return 900;                # TODO
}

# Helpers for making file/link/dir
sub file {
    my ( $class, %opt ) = @_;

    my $perms = defined $opt{'mode'} ? int( $opt{'mode'} ) : 0666;
    $opt{'mode'} = ( $perms ^ umask ) & S_IFREG;

    return $class->new( \%opt );
}

sub dir {
    my ( $class, %opt ) = @_;

    my $perms = defined $opt{'mode'} ? int( $opt{'mode'} ) : 0777;
    $opt{'mode'} = ( $perms ^ umask ) & S_IFDIR;

    return $class->new( \%opt );
}

sub link {
    my ( $class, $target_file, %opt ) = @_;

    length $target_file or die("Symlinks must point to a file.");

    $opt{'readlink'} = $target_file;
    $opt{'mode'}     = 0777 & S_IFLNK;

    return $class->new( \%opt );
}

sub readlink {
    my ($self) = @_;

    return $self->{'readlink'};
}

sub is_link {
    my ($self) = @_;

    return ( length $self->{'readlink'} && $self->{'mode'} & S_IFLNK ) ? 1 : 0;
}

sub resize {
    my ( $self, $new_size ) = @_;

    $self->{'size'} = abs( int( $new_size || 0 ) );
    $self->{'blocks'} = $self->{'size'} / abs( $self->{'blksize'} || 1 );
}

sub chmod {
    my ( $self, $mode ) = @_;

    $mode = int($mode) | S_IFPERMS;

    $self->{'mode'} = ( $self->{'mode'} & S_IFMT ) + $mode;

    return $mode;
}

sub mtime {
    my ( $self, $time ) = @_;

    $time = time unless defined $time && $time =~ m/^[0-9]+$/;
    $self->{'mtime'} = $time;
}

sub ctime {
    my ( $self, $time ) = @_;

    $time = time unless defined $time && $time =~ m/^[0-9]+$/;
    $self->{'ctime'} = $time;
}

sub atime {
    my ( $self, $time ) = @_;

    $time = time unless defined $time && $time =~ m/^[0-9]+$/;
    $self->{'atime'} = $time;
}

1;
