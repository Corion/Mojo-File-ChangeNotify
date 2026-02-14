package Mojo::File::ChangeNotify 0.01;
use 5.020;
use Mojo::Base 'Mojo::EventEmitter', -signatures;
use Mojo::File::ChangeNotify::WatcherProcess 'watch';
use Mojo::IOLoop::Subprocess;

=head1 NAME

Mojo::File::ChangeNotify - turn file changes into Mojo events

=head1 SYNOPSIS

  my $watcher =
    Mojo::File::ChangeNotify->instantiate_watcher
        ( directories => [ '/my/path', '/my/other' ],
          filter      => qr/\.(?:pm|conf|yml)$/,
          on_change   => sub( $watcher, @event_lists ) {
              ...
          },
        );

  # alternatively
  $watcher->on( 'change' => sub( $watcher, @event_lists ) {
      ...
  });
  # note that the watcher might need about 1s to start up

=head1 IMPLEMENTATION

L<File::ChangeNotify> only supports blocking waits or polling as an
interface. This module creates a subprocess that blocks and communicates
the changes to the main process.

=cut

has 'watcher';

sub _spawn_watcher( $self, $args ) {
    my $subprocess = Mojo::IOLoop::Subprocess->new();
    #use Data::Dumper; warn Dumper( File::ChangeNotify->usable_classes );
    $subprocess->run( sub( $subprocess ) {
        watch( $subprocess, $args )
    }, sub ($subprocess, $err, @results ) {
        say "Subprocess error: $err" and return if $err;
        say "Surprising results: @results"
            if @results;
    }
    );
}

sub instantiate_watcher( $class, %args ) {
    my $handler = delete $args{ on_change };
    my $self = $class->new();
    if( $handler ) {
        $self->on( 'change' => $handler );
    }

    $self->watcher( $self->_spawn_watcher( \%args ));
    $self->watcher->on('progress' => sub( $w, $events ) {
        $self->emit('change' => $events )
    });

    return $self;
}

1;
