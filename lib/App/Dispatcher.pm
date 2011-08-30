package App::Dispatcher;
use strict;
use warnings;
use Carp qw/croak confess/;
use Getopt::Long::Descriptive qw/describe_options/;
use File::Spec::Functions qw/catdir catfile splitdir/;
use File::Find;
use File::Basename;
use Storable qw/dclone/;
use Template;
use Perl::Tidy qw/perltidy/;
use Pod::Tidy;
use File::Slurp;
use File::ShareDir qw/dist_dir/;
use Sub::Exporter -setup => {
    exports => [
        qw/
          run_app_dispatcher
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
no warnings 'redefine';    # due to bootstrap/build time effects

our $VERSION = '0.11';

# partially stolen from ExtUtils::MakeMaker
sub _abstract {
    my ( $class, $file ) = @_;

    confess '_abstract($class,$file)' unless ( $class and $file );

    my $result;
    open my $fh, "<", $file or return;

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
    return $result;
}

# Helper sub.
sub run_app_dispatcher {
    my $class = shift;
    local @ARGV = ( @_, qw/--class/, $class );
    my ( $opt, $usage ) = describe_options( 'x', opt_spec(), arg_spec() );

    _app_dispatcher( $class, $opt );
}

sub _app_dispatcher {
    my $class = shift || croak '_app_dispatcher($class,$opt)';
    my $opt   = shift || croak '_app_dispatcher($class,$opt)';

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
    require $classfile;

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
        class     => '__App__Dispatcher__Test__Class__',
        version   => $VERSION,
        add_debug => $opt->add_debug,
        structure => {},
    };

    # Make sure @INC is good for 'require'
    unshift @INC, @{ $opt->inc }, @paths;

    my @gopts;

    if ( $opt->add_short_help ) {
        push( @gopts, [ 'help|h', 'print usage message and exit' ] );
    }
    elsif ( $opt->add_help ) {
        push( @gopts, [ 'help', 'print usage message and exit' ] );
    }

    if ( $opt->add_debug ) {
        push( @gopts,
            [ 'debug-dispatcher', 'print App::Dispatcher debug information' ] );
    }

    push( @gopts, eval { $class->gopt_spec } );

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

        my $abstract = _abstract( $plugin, $file );
        if ( !$abstract ) {
            ( my $pod = $file ) =~ s/\.pm/\.pod/;
            $abstract = _abstract( $plugin, $pod ) || '(unknown)',;
        }

        my $refp = $ref->{structure}->{$plugin} = {
            name          => $name,
            class         => $plugin,
            abstract      => $abstract,
            order         => 2**31 - 1,     # just a big number, nothing special
            opt_spec      => dclone \@gopts,
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
                    ( my $x = uc $_->[0] ) =~ s/(.*)[|=].*/$1/;
                    exists $_->[2]->{required} ? "$x" : "[$x]";
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

    my @tpaths;
    foreach my $path (
        'share',
        dirname($0) . '/../share',
        eval { dist_dir('App-Dispatcher') }
      )
    {
        next unless -d $path;
        push( @tpaths, $path );
    }

    my $template = Template->new(
        INCLUDE_PATH => \@tpaths,
        EVAL_PERL    => 1,
    ) || die Template->error;

    my $txt;
    $template->process( 'Dispatcher.pm.tt', $ref, \$txt )
      || die "Template: " . $template->error . "\n";

    eval "$txt";    ## no critic
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
        [ 'add-help|H',     "add a '--help' option to every command", ],
        [ 'add-short-help', "add a '-h' option to every command", ],
        [ 'add-debug|D',    "add a global '--debug-dispatcher' option", ],
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

sub run {
    my ( $self, $opt ) = @_;

    _app_dispatcher( $opt->class, $opt );
}

1;
