package App::Dispatcher;
use Carp qw/croak confess/;
use Getopt::Long::Descriptive qw/describe_options/;
use File::Spec::Functions qw/catdir catfile splitdir/;
use File::Find;
use Template;
use Perl::Tidy qw/perltidy/;
use Pod::Tidy;
use File::Slurp;
use File::ShareDir qw/dist_dir/;
use Sub::Exporter -setup => {
    exports => [
        qw/
          app_dispatcher
          app_dispatcher_opts
          /,
    ],
    groups => {
        default => [
            qw/
              /,
        ],
    },

};
use lib 'lib';
use strict;
use warnings;
no warnings 'redefine';    # due to bootstrap/build time effects

our $VERSION = '0.09';

# partially stolen from ExtUtils::MakeMaker
sub _abstract {
    my ( $class, $pm_file ) = @_;

    confess '_abstract($class,$pm_file)' unless ( $class and $pm_file );

    my $result;
    open my $fh, "<", $pm_file or return "(unknown)";

    local $/ = "\n";
    my $inpod;

    while ( local $_ = <$fh> ) {
        $inpod = /^=cut/ ? !$inpod : $inpod
          || /^=(?!cut)/;    # =cut toggles, it doesn't end :-/

        next unless $inpod;
        chomp;
        next unless /^(?:$class\s-\s)(.*)/;
        $result = $1;
        last;
    }
    return $result || "(unknown)";
}

sub app_dispatcher {
    my $class = shift || croak 'app_dispatcher($class,$opt)';
    my $opt   = shift || croak 'app_dispatcher($class,$opt)';

    $opt->{add_mtime_check} = 1 if $opt->{add_debug};

    my $outdir = catdir( 'lib', split( '::', $class ) );
    my $output = catfile( $outdir, 'Dispatcher.pm' );

    my @paths = @{ $opt->path };

    # Do the searching manually so we don't pick up
    # command classes installed somewhere else.
    my $classfile;
    foreach my $dir (@paths) {
        my $try = catdir( $dir, split( '::', $class ) ) . '.pm';
        if ( $opt->verbose ) {
            print "Trying $try\n";
        }
        if ( -e $try ) {
            $classfile = $try;
            print "Found $classfile\n" if $opt->verbose;
            last;
        }
    }

    if ( !$classfile ) {
        die "Cannot find class '$class' (searched: @paths)\n";
    }

    my @plugins = ($class);
    my @files   = ($classfile);

    foreach my $dir (@paths) {
        my $realdir = catdir( $dir, split( '::', $class ) );
        if ( $opt->verbose ) {
            print "Searching in $dir\n";
        }
        next unless -d $realdir;
        find(
            sub {
                return unless -f $_;
                return unless $_ =~ m/\.pm$/;
                my $p = $File::Find::name;
                $p =~ s!^$dir!!;
                $p =~ s/\.pm//;
                $p = join( '::', splitdir($p) );
                $p =~ s/^:://g;
                return if ( $p eq $class . '::Dispatcher' );
                push( @plugins, $p );
                push( @files,   $File::Find::name );
            },
            $realdir
        );
    }

    my $ref = {
        class           => '__App__Dispatcher__Test__Class__',
        version         => $VERSION,
        add_debug       => $opt->add_debug,
        add_mtime_check => $opt->add_mtime_check,
        structure       => {},
    };

    # Make sure @INC is good for 'require'
    unshift @INC, @{ $opt->inc }, @paths;

    foreach my $plugin (@plugins) {
        my $file = shift @files;
        if ( $opt->verbose ) {
            print "Working $file\n";
        }
        require $file;

        ( my $name  = $plugin ) =~ s/^${class}:://;
        ( $name     = $plugin ) =~ s/.*:://;
        ( my $usage = $plugin ) =~ s/^${class}/usage: %c/;
        $usage =~ s/::/ /g;

        my @opt;
        if ( $opt->add_help ) {
            push( @opt, [ 'help|h', 'print usage message and exit' ] );
        }
        if ( $opt->add_debug and $plugin eq $class ) {
            push(
                @opt,
                [
                    'debug-dispatcher',
                    'print App::Dispatcher debug information'
                ]
            );
        }

        my $refp = $ref->{structure}->{$plugin} = {
            name     => $name,
            class    => $plugin,
            abstract => _abstract( $plugin, $file ),
            order         => 2**31 - 1,    # just a big number, nothing special
            opt_spec      => \@opt,
            arg_spec      => [],
            require_order => 0,
            getopt_conf   => [],
        };

        if ( $plugin->can('order') ) {
            $refp->{order} = $plugin->order;
        }

        if ( $plugin->can('opt_spec') ) {
            push( @{ $refp->{opt_spec} }, $plugin->opt_spec );
        }

        if ( $plugin->can('arg_spec') ) {
            $refp->{arg_spec} = [ $plugin->arg_spec ];
        }

        $refp->{usage_desc} = $usage;
        $refp->{usage_desc} .= ' [options]'
          if @{ $refp->{opt_spec} };

        foreach my $arg ( @{ $refp->{arg_spec} } ) {
            unless ( $arg->[0] =~ /[=:]/ ) {
                warn "$plugin: setting type spec to '=s': $arg->[0]\n";
                $arg->[0] .= '=s';
            }
            if ( @$arg < 3 ) {
                $arg->[2] = {};
            }
            delete $arg->[2]->{required} unless $arg->[2]->{required};
        }

        if ( @{ $refp->{arg_spec} } ) {
            $refp->{usage_desc} .= ' ' . join(
                ' ',
                map {
                    ( my $x = $_->[0] ) =~ s/(.*)[|=].*/$1/;
                    exists $_->[2]->{required} ? "<$x>" : "[<$x>]";
                  } @{ $refp->{arg_spec} }
            );
        }

        if ( $plugin eq $class and @plugins > 1 ) {
            $refp->{usage_desc} .= ' [...]';
        }

        # Wipe away all our hard work
        if ( $plugin->can('usage_desc') ) {
            $refp->{usage_desc} = $plugin->usage_desc;
        }

        if ( $plugin->can('abstract') ) {
            $refp->{abstract} = $plugin->abstract;
        }

        if ( eval { $plugin->require_order } ) {
            $refp->{require_order} = 1;
            $refp->{getopt_conf}   = ['require_order'];
        }
        else {
            $refp->{getopt_conf} = ['permute'];
        }
    }

    print "Generating $output\n";

    my $template = Template->new(
        INCLUDE_PATH =>
          [ 'share', '../share', eval { dist_dir('App-Dispatcher') } || () ],
        EVAL_PERL => 1,
    ) || die Template->error;

    my $txt;
    $template->process( 'Dispatcher.pm.tt', $ref, \$txt )
      || die "Template: " . $template->error . "\n";

    eval "$txt";
    if ( my $err = $@ ) {
        my $i = 0;
        map { printf STDERR "%-03s $_\n", $i++ } split( /\n/, $txt );
        die $err;
    }

    my $tidy;
    $txt =~ s/__App__Dispatcher__Test__Class__/$class/g;
    perltidy( source => \$txt, destination => \$tidy, argv => [] );

    if ( -e $output && -w $output && !$opt->force ) {
        die "$output is writable! (use -f to overwrite)\n";
    }

    if ( !$opt->dry_run ) {
        if ( !-d $outdir ) {
            mkdir $outdir || die "mkdir: $!";
        }

        unlink $output || die "unlink: $!";
        write_file( $output, $tidy );

        Pod::Tidy::tidy_files(
            files    => [$output],
            inplace  => 1,
            nobackup => 1,
            columns  => 72
        );
        chmod( 0444, $output ) || die "chmod: $!";
    }
    return 0;
}

sub opt_spec {
    (
        [ 'add-help|H',        "add a '--help' option to every command", ],
        [ 'add-debug|D',       "add a global '--debug-dispatcher' option", ],
        [ 'add-mtime-check|M', "check for out of date command files" ],
        [ 'inc|I=s@', "add to the perl \@INC array", { default => [] } ],
        [
            'path|p=s@',
            "directory to search for command classes",
            { default => ['lib'] }
        ],
        [ 'dry-run|n', "do not write out files", ],
        [ 'force|f',   "force overwrite of existing files", ],
        [ 'verbose|v', "run loudly" ],
    );
}

sub arg_spec {
    ( [ 'class=s', "root class of your command packages", { required => 1 } ],
    );
}

sub app_dispatcher_opts {
    local @ARGV = @_;
    my ( $opt, $usage ) = eval {
        describe_options(
            '(not a user
    command)', ( opt_spec, arg_spec )
        );
    };

    die "Invalid options: $@" if ($@);
    return $opt;
}

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

The name space under which the command classes will be searched for.

=item $opt

A L<Getopt::Long::Descriptive::Opts> (or equivalent) object with the
following methods:

=over 4

=item add_help

Add a '--help' option to every command.

=item add_debug

Add a global '--debug-dispatcher' option. Useful for debugging the
actual options your command classes are receiving. Automatically turns
on 'add_mtime_check'.

=item add_mtime_check

Warn at dispatch time if the command class file has a more recent
modification date than the dispatch class.

=item inc

Arrayref to add to @INC.

=item path

Arrayref of directories to search for command classes.

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

=over 4

=item app_dispatcher_opts( @args )

=back

The command classes may have the following methods defined:

=over 4

=item require_order

Optional. An boolean to set the L<Getopt::Long> option 'require_order'
when true, or set option 'permute' (the default) when false (or not
defined).

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

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 3 of the License, or (at your
option) any later version.

=cut

z vim: set tabstop=4 expandtab:
