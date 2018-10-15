# Copyright (c) 2018, cPanel, LLC.
# All rights reserved.
# http://cpanel.net
#
# This is free software; you can redistribute it and/or modify it under the
# same terms as Perl itself. See L<perlartistic>.

package Test::MockFile::FileHandle;

use strict;
use warnings;

my $files_being_mocked = \%Test::MockFile::files_being_mocked;

sub TIEHANDLE {
    my ( $class, $mode, $file ) = @_;

    _validate_open_mode( $mode, $file // '' );
    length $file or die("No file name passed!");

    my $self = bless {
        'mode' => $mode,
        'file' => $file,
        'data' => $files_being_mocked->{$file},
        'tell' => 0,
    }, $class;

    # Need to move to EOF if the file was opened for append.
    if ( $self->{'mode'} eq '>>' ) {
        $self->{'tell'} = length $self->{'data'}->{'contents'};
    }
    elsif ( $self->{'mode'} eq '>' ) {    #truncate.
        $self->{'data'}->{'contents'} = '';
    }

    return $self;
}

sub _validate_open_mode {
    my ( $mode, $file ) = @_;

    defined $mode or die "Unknown file mode provided to open $file!";
    return if ( $mode =~ m/^(>|>>|<)$/ );
    die "Unknown file mode '$mode' provided to open $file!";
}

# This method will be triggered every time the tied handle is printed to with the print() or say() functions.
# Beyond its self reference it also expects the list that was passed to the print function.
sub PRINT {
    my ( $self, @list ) = @_;

    if ( $self->{'mode'} eq '<' ) {
        $! = 'Bad file descriptor';
        return;
    }

    my $starting_bytes = length $self->{'data'}->{'contents'};
    $self->{'data'}->{'contents'} .= $_ foreach @list;

    return length( $self->{'data'}->{'contents'} ) - $starting_bytes;
}

# This method will be triggered every time the tied handle is printed to with the printf() function.
# Beyond its self reference it also expects the format and list that was passed to the printf function.
sub PRINTF {
    my $self = shift;

    return $self->( sprintf(@_) );
}

# This method will be called when the handle is written to via the syswrite function.
sub WRITE {
    my ( $self, $buf, $len, $offset ) = @_;

    unless ( $len =~ m/^-?[0-9.]+$/ ) {
        $! = qq{Argument "$len" isn't numeric in syswrite at ??};
        return 0;
    }

    $len = int($len);    # Perl seems to do this to floats.

    if ( $len < 0 ) {
        $! = qq{Negative length at ???};
        return 0;
    }

    my $strlen = strlen($buf);
    if ( $strlen > abs($len) ) {
        $! = q{Offset outside string at ???.};
        return 0;
    }

    if ( $offset < 0 ) {
        $offset = $strlen + $offset;
    }

    return $self->PRINT( substr( $buf, $len, $offset ) );
}

# This method is called when the handle is read via <HANDLE> or readline HANDLE .
sub READLINE {
    my ($self) = @_;

    my $tell = $self->{'tell'};
    my $new_tell = index( $self->{'data'}->{'contents'}, $/, $tell ) + length($/);

    if ( $new_tell == 0 ) {
        $new_tell = length( $self->{'data'}->{'contents'} );
    }
    return undef if ( $new_tell == $tell );    # EOF

    my $str = substr( $self->{'data'}->{'contents'}, $tell, $new_tell - $tell );
    $self->{'tell'} = $new_tell;
    return $str;
}

# This method will be called when the getc function is called.
sub GETC {
    my ($self) = @_;

}

# This method will be called when the handle is read from via the read or sysread functions.
sub READ {
    my ($self) = @_;
    ...;
}

# This method will be called when the handle is closed via the close function.
sub CLOSE {
    my ($self) = @_;

    delete $self->{'data'}->{'fh'};
    untie $self;

    return 1;
}

# As with the other types of ties, this method will be called when untie happens.
# It may be appropriate to "auto CLOSE" when this occurs. See The untie Gotcha below.
sub UNTIE {
    my $self = shift;
    $self->CLOSE;
    print "UNTIE!\n";
}

# As with the other types of ties, this method will be called when the tied handle is
# about to be destroyed. This is useful for debugging and possibly cleaning up.
sub DESTROY {
    my ($self) = @_;

    $self->CLOSE;
}

# This method will be called when the eof function is called.
sub EOF {
    my ($self) = @_;

    if ( $self->{'mode'} ne '<' ) {
        warn q{Filehandle STDOUT opened only for output};
    }
    return $self->{'tell'} == length $self->{'data'}->{'contents'};
}

sub BINMODE {
    my ($self) = @_;
    ...;
}

sub OPEN {
    my ($self) = @_;
    ...;
}

sub FILENO {
    my ($self) = @_;
    ...;
}

sub SEEK {
    my ($self) = @_;
    ...;
}

sub TELL {
    my ($self) = @_;
    return $self->{'tell'};
}

1;
