package App::Dispatcher::Command;
use App::Dispatcher;
use strict;
use warnings;
no warnings 'redefine'; # due to bootstrap/build time effects

our $VERSION = '0.03';

sub opt_spec {(
    [ 'add-help',  "add a '--help' option to every command",],
    [ 'inc-dirs|i=s',"directories to search for commands",
        {default => 'lib'}],
    [ 'dry-run|n',  "do not write out files",],
    [ 'force|f',    "force overwrite of existing files",],
    [ 'verbose|v',  "print code during the build" ],
)}


sub arg_spec {(
    [ 'class=s', "root class of your command packages", { required => 1 } ],
)}


sub run {
    my ( $self, $opt ) = @_;

    app_dispatcher( $opt->class, $opt );
}


1;

__END__


=head1 NAME

App::Dispatcher::Command - build command line applications in Perl

=head1 DESCRIPTION

This is the command class for L<app-dispatcher>(1). It has the
following methods:

=over 4

=item opt_spec

The option specification.

=item arg_spec

The argument specification.

=item run

The actual run commands.

=back

=head1 SEE ALSO

L<App::Dispatcher::Tutorial>(3p), L<App::Dispatcher>(3p),
L<app-dispatcher>

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 Mark Lawrence E<lt>nomad@null.netE<gt>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

=cut
