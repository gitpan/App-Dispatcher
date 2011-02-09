package App::Dispatcher;
use Carp qw/croak confess/;
use File::Spec::Functions qw/catdir catfile splitdir/;
use File::Find;
use Pod::Simple;
use Template;
use File::ShareDir qw/dist_dir/;
use Sub::Exporter -setup => {
    exports => [ qw/
        app_dispatcher
        /,
    ],
    groups => {
        default => [ qw/
            /,
        ],
    },

};
use lib 'lib';
use strict;
use warnings;
no warnings 'redefine'; # due to bootstrap/build time effects

our $VERSION = '0.05';

# partially stolen from ExtUtils::MakeMaker
sub _abstract {
    my ( $class, $pm_file ) = @_;

    confess '_abstract($class,$pm_file)' unless ( $class and $pm_file );

    my $result;
    open my $fh, "<", $pm_file or return "(unknown)";

    local $/ = "\n";
    my $inpod;

    while (local $_ = <$fh>) {
        $inpod = /^=cut/ ? !$inpod : $inpod || /^=(?!cut)/; # =cut toggles, it doesn't end :-/

        next unless $inpod;
        chomp;
        next unless /^(?:$class\s-\s)(.*)/;
        $result = $1;
        last;
    }
    return $result || "(unknown)";
}


sub app_dispatcher {
    my $caller = caller;

    my $class  = shift || croak 'app_dispatcher($class,$opt)';
    my $opt    = shift || croak 'app_dispatcher($class,$opt)';

    # Only find modules underneath us - not the whole search path
    my @dirs = map { glob $_ } split(/,/, $opt->inc_dirs);

    my $classfile;
    foreach my $dir ( @dirs ) {
        my $try = catdir( $dir, split('::', $class ) ) .'.pm';
        $classfile = $try if ( -e $try );
    }

    if ( ! $classfile ) {
        die "Cannot find class '$class' (searched: @dirs)\n";
    }

    my @plugins = ( $class );
    my @files   = ( $classfile );

    foreach my $dir ( @dirs ) {
        my $realdir = catdir( $dir, split('::', $class ) );
        next unless -d $realdir;
        find( sub {
            return unless -f $_;
            return unless $_ =~ m/\.pm$/;
            my $p = $File::Find::name;
            $p =~ s!^$dir!!;
            $p =~ s/\.pm//;
            $p = join( '::', splitdir($p) );
            $p =~ s/^:://g;
            return if ( $p eq $class .'::Dispatcher' );
            push( @plugins, $p ); 
            push( @files, $File::Find::name ); 
            print "Found $File::Find::name\n";
        }, $realdir );
    }

    my $ref = {
        class     => $class,
        version   => $VERSION,
        structure => {},
    };

    foreach my $plugin ( @plugins ) {
        my $file =  shift @files;
        require $file;

        (my $name = $plugin ) =~ s/^${class}:://;
        ( $name = $plugin ) =~ s/.*:://;
        (my $usage = $plugin ) =~ s/^${class}/usage: %c/;
        $usage =~ s/::/ /g;

        my $refp = $ref->{structure}->{$plugin} = {
            name        => $name,
            class       => $plugin,
            abstract    => _abstract( $plugin, $file ),
            order       => 2**31-1, # just a big number, nothing special
            opt_spec    => $opt->add_help
                ? [ ['help', 'print usage message and exit' ] ]
                : [],
            arg_spec    => [],
        };

        if ( $plugin->can('order') ) {
            $refp->{order} = $plugin->order;
        }


        if ( $plugin->can('opt_spec') ) {
            push( @{$refp->{opt_spec}}, $plugin->opt_spec );
        }

        if ( $plugin->can('arg_spec') ) {
            $refp->{arg_spec} = [ $plugin->arg_spec ];
        }

        $refp->{usage_desc} = $usage;
        $refp->{usage_desc} .= ' [options]'
            if @{ $refp->{opt_spec} };
            
        foreach my $arg ( @{ $refp->{arg_spec} } ) {
            unless ( $arg->[0] =~ /[|=]/) {
                warn "$plugin: setting type spec to '=s': $arg->[0]\n";
                $arg->[0] .= '=s';
            }
            if ( @$arg < 3 ) {
                $arg->[2] = {};
            }
            delete $arg->[2]->{required} unless $arg->[2]->{required};
        }

        if ( @{ $refp->{arg_spec} } ) {
            $refp->{usage_desc} .= ' '.
                join(' ', map {
                    (my $x = $_->[0]) =~ s/(.*)[|=].*/$1/;
                    exists $_->[2]->{required} ? "<$x>" : "[<$x>]";
                } @{ $refp->{arg_spec}} );
        }

        if ( $plugin->can('usage_desc') ) {
            $refp->{usage_desc} = $plugin->usage_desc;
        }

        if ( $plugin->can('abstract') ) {
            $refp->{abstract} = $plugin->abstract;
        }

    }

    my $txt;
    my $file = 'Dispatcher.pm.tt';

    my $template = Template->new(
        INCLUDE_PATH => [ 'share', 'templates',
            eval { dist_dir('App-Dispatcher') } || () ],
        EVAL_PERL => 1,
    ) || die Template->error;

    $template->process( $file, $ref, \$txt )
        || die "Template: ". $template->error ."\n";

    eval "$txt";

    my $err = $@;

    if ( $err or $opt->verbose ) {
        my $i = 0;
        foreach ( split(/\n/, $txt) ) {
            $err 
                ? printf STDERR "%3d %s\n", ++$i, $_
                : printf STDOUT "%3d %s\n", ++$i, $_;
        }
        print "\n";
    }
    die "$err\n" if $err;

    my $output = catfile('lib', split('::', $class ), 'Dispatcher.pm');

    if ( ! $opt->dry_run ) {
        if ( -e $output && -w $output && ! $opt->force) {
            die "$output is writable! (use -f to overwrite)";
        }
        print "Writing $output\n";
        unlink $output;
        $template->process( $file, $ref, $output )
            || die $template->error;
        chmod(0444, $output) || die "chmod: $!";
    }
    return 0;
}


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

App::Dispatcher - generate command-line dispatcher classes

=head1 SYNOPSIS

    use App::Dispatcher qw/app_dispatcher/;
    app_dispatcher( $class, $opt );

=head1 DESCRIPTION

This is the interface documentation for the B<App::Dispatcher> class,
which is generally not used directly by application authors.  To make
use of B<App::Dispatcher> in your application you most likely want to
be reading L<App::Dispatcher::Tutorial> instead.

B<App::Dispatcher> is a the implementation for the L<app-dispatcher>(1)
command. The implementation is contained in a single subroutine with
that takes two mandatory arguments:

=over 4

=item app_dispatcher( $class, $opt )

=over 4

=item $class

The name space under which the command classes
will be searched for.

=item $opt

A L<Getopt::Long::Descriptive::Opts> (or equivalent) object
with the following methods:

=over 4

=item inc_dirs

A comma-separated list of directories to search in.

=item verbose

Print out extra details during execution.

=item dry_run

Don't write out any files to disk.

=item force

Force the overwriting of existing writeable files.

=back

=back

=back

A successful run of app_dispatcher() results in the creation of 
'lib/$class/Dispatcher.pm', which is based on the Command Classes found
under 'lib/$class'.

The command classes may have the following methods defined:

=over 4

=item order

Optional. An integer to force the order in which commands are
displayed.

=item usage_desc

Optional. The string used for error messgaes. Will be auto-generated
from the opt_spec and arg_spec methods if not implemented.

=item opt_spec

Optional, but at least one of opt_spec or arg_spec should in most cases
be implemented. A list of option definitions which will be passed to
the describe_options method of Getopt::Long::Descriptive.

=item arg_spec

Optional, but at least one of opt_spec or arg_spec should in most cases
be implemented. A list of argument definitions which will be passed to
the describe_options method of Getopt::Long::Descriptive.

=item run

Optional, but it only makes sense to be left unimplemented if the
command requires subcommands. This is the method where the real work is
performed.

=item abstract

Optional. A brief description of the command. Will be pulled from the
POD documentation if not implemented.

=back

B<App::Dispatcher> is also its own Command Class. That is, it
implements the opt_spec(), arg_spec() and run() methods.

=head1 SEE ALSO

L<app-dispatcher>(1), L<App::Dispatcher::Tutorial>(3p)

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

=cut

# vim: set tabstop=4 expandtab:
