package Test::MockFileSys;

use Test::MockFile ();
use Scalar::Util   ();

my $singleton;

sub _automock_hook;

sub import {
    my ( $class, @args ) = @_;

    foreach my $arg (@args) {
        Test::MockFile->import($arg) if ( $arg =~ m/^(?:no)strict/i );
    }

    Test::MockFile::set_strict_mode_automock( \&_automock_hook );

    return;
}

sub is_strict_mode {
    return $Test::MockFile::STRICT_MODE_STATUS == Test::MockFile::STRICT_MODE_DISABLED() ? 0 : 1;
}

sub _automock_hook {
    my ($path) = @_;
    return unless ref $singleton;

    my $mock = Test::MockFile->new( { 'path' => $path, 'contents' => undef } );
    return $singleton->{'files'}->{ $mock->path } = $mock;
}

sub new {
    my ( $class, @args ) = @_;

    return $singleton if defined $singleton;

    !defined $singleton or die("$class has already been instantiated");

    my $self = $singleton = bless {}, $class;
    Scalar::Util::weaken($singleton);

    $self->init;

    return $self;
}

sub init {
    my ($self) = @_;

    $self->{'files'} = {};

    return;
}

sub get_mocked_path {
    my ( $self, $path, $type ) = @_;
    my $abs_path = Test::MockFile::_abs_path_to_file($path);
    my $m        = $self->{'files'}->{$abs_path};
    return $m if $m;    # We hold the object. Just return it.

    # Did someone directly mock it in T::MF? If so we're going to store it here also.
    $m = $Test::MockFile::files_being_mocked{$abs_path};
    if ($m) {
        $self->{'files'}->{$abs_path} = $m;
        return $m;
    }

    return unless defined $type && length $type;

    # We're going to have to instantiate it and we will own it.
    return $self->{'files'}->{$abs_path} = Test::MockFile->can($type)->( 'Test::MockFile', $abs_path );
}

sub dir {
    my ( $self, $path ) = @_;

    return $self->get_mocked_path( $path, 'dir' );
}

sub file {
    my ( $self, $path ) = @_;

    return $self->get_mocked_path( $path, 'file' );
}

sub symlink {
    my ( $self, $path ) = @_;

    return $self->get_mocked_path( $path, 'symlink' );
}

sub path {
    my ( $self, $path ) = @_;
    return $self->get_mocked_path($path);
}

sub unmock {
    my ( $self, $path ) = @_;
    my $mock = $self->path($path);

    delete $self->{'files'}->{ $mock->path };
}

## make the thing and set perms, etc.
#$fs->write_file('/foo/bar', "", { perms => 0755 });
#$fs->symlink('data', '/foo/link');

sub write_file {
    my ( $self, $path, $content, $stats ) = @_;

    my $mock = $self->file($path);
    $mock->contents($content);

    #$mock->set_stats($stats) if ref $stats;

    return $mock;
}

sub file_contents {
    my ( $self, $path ) = @_;

    my $mock = $self->file($path);
    return $mock->contents;
}

## This is broken right now.
#sub symlink {
#    my ($self, $path, $content, $stats );
#
#    my $mock = $self->symlink($path);
#    $mock->{'readlink'} = $content if defined $content;
#    $mock->set_stats($stats) if ref $stats;
#
#    return $mock;
#}

sub mkdir {
    my ( $self, $path, $perms, $stats ) = @_;

    my @paths = split($path);
    foreach {
        my $mock = $self->dir($path);
    }
    mkdir $path;

    # TODO: if we do $mock->chmod, it doesn't work the same :-\
    chmod( $perms, $path ) if length $perms;

    # TODO: support mtime modification, etc.
    #$mock->set_stats($stats) if ref $stats;

    return $mock;
}

## automock in strict mode.
#symlink('data', '/foo/link');
#mkdir '/foo', 0755;
#chmod 0755, '/foo/bar';
#unlink '/foo/link';
#
## Get the object

sub DESTROY {
    undef $singleton;    # Weakened variable. we need to clear it.
}

1;
