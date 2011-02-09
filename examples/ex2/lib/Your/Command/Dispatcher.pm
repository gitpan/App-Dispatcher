# Do not modify!
# This file is autogenerated and your changes will be overwritten.
package Your::Command::Dispatcher;
use Getopt::Long::Descriptive qw/describe_options prog_name/;
use strict;
use warnings;

our $VERSION = '0.01';

my $me = prog_name;

my $program = {
  'Your::Command' => {
    'usage_desc' => 'usage: %c [options] <database>',
    'opt_spec' => [
      [
        'help',
        'print usage message and exit'
      ],
      [
        'dry-run|n',
        'print out SQL instead of running it'
      ],
      [
        'drop-tables|D',
        'DROP TABLEs before deploying'
      ]
    ],
    'arg_spec' => [
      [
        'database=s',
        'production|development',
        {
          'required' => 1,
          'default' => 'development'
        }
      ]
    ],
    'order' => 2147483647,
    'name' => 'Command',
    'abstract' => '(unknown)',
    'class' => 'Your::Command'
  }
};



sub _commands {
    my $cmd = shift;
    require List::Util;

    my $max = 4 + List::Util::max(map { length $_->{name} } values %$program);
    my @commands = map {
        sprintf("    %-${max}s %s\n", $_->{name}, $_->{abstract})
    } sort {
        $a->{order} <=> $b->{order}
    } grep {
        $_->{class} =~ m/${cmd}::/ and not
        $_->{class} =~ m/${cmd}::.*:/
    } values %$program;
    return @commands;
}


sub run {

    my $cmd = 'Your::Command';

    # Global options, possibly actual (main) command options
    my ($gopt, $gusage) = describe_options(
        $program->{$cmd}->{usage_desc},
        @{ $program->{$cmd}->{opt_spec}},
        { getopt_conf => [ 'require_order' ], },
    );

    if ( $gopt->can('help') && $gopt->help ) {
        print STDOUT $gusage->text;
        if ( my @commands = _commands( $cmd ) ) {
            print STDERR "\nCommands:\n";
            print STDERR join('', @commands );
        }
        exit 1;
    }


    # Look for a subcommand
    while ( @ARGV && exists $program->{$cmd .'::'. $ARGV[0]} ) {
        $cmd = $cmd .'::'. shift @ARGV;
    }

    my ($opt, $usage) = ($gopt, $gusage);
    if ( $cmd ne 'Your::Command' ) {
        ($opt, $usage) = describe_options(
            $program->{$cmd}->{usage_desc},
            @{ $program->{$cmd}->{opt_spec} },
            { getopt_conf => [ 'require_order' ], },
        );
    }

    if ( $opt->can('help') && $opt->help ) {
        print STDOUT $usage->text;
        if ( my @commands = _commands( $cmd ) ) {
            print STDERR "\nCommands:\n";
            print STDERR join('', @commands );
        }
        exit 1;
    }

    my @arg_spec = @{ $program->{$cmd}->{arg_spec} };

    # Still have an argument, but no expecting one?
    if ( @ARGV > @arg_spec ) {
        print STDERR "Too many arguments\n";
        print STDERR $usage->text;
        exit 2;
    }
    # Expecting an argument but don't have one?
    elsif ( @ARGV < @arg_spec ) {
        if ( $arg_spec[0]->[2]->{required} ) {
            my $x = $arg_spec[0]->[0];
            $x =~ s/[\|=].*//;
    #        print STDERR "Missing argument: <$x>\n\n";
            print STDERR $usage->text;
            if ( my @commands = _commands( $cmd ) ) {
                print STDERR "\nCommands:\n";
                print STDERR join('', @commands );
            }
            exit 2;
        }
    }


    my @newargv;


    foreach my $opt_spec ( @{ $program->{$cmd}->{opt_spec} } ) {
        my $x = $opt_spec->[0];
        $x =~ s/[\|=].*//;
        (my $x2 = $x) =~ s/-/_/;

        if ( $opt_spec->[0] =~ /=/ ) {
            if ( $cmd eq 'Your::Command' ) {
                push( @newargv, '--'.$x, $gopt->$x2 ) if ( exists
                $gopt->{$x2} );
            } else {
                push( @newargv, '--'.$x, $opt->$x2 ) if ( exists
                $opt->{$x2} );
            }
        }
        else {
            if ( $cmd eq 'Your::Command' ) {
                push( @newargv, '--'.$x) if ( exists
                $gopt->{$x2} );
            } else {
                push( @newargv, '--'.$x ) if ( exists
                $opt->{$x2} );
            }
        }
    }

    foreach my $arg ( @arg_spec ) {
        my $val = shift @ARGV;
        my $x = $arg->[0];
        $x =~ s/[|=].*//;
        push( @newargv, '--'.$x, $val );
    }

    @ARGV = @newargv;

    ($opt, $usage) = describe_options(
        $program->{$cmd}->{usage_desc},
        @{ $program->{$cmd}->{opt_spec} },
        @{ $program->{$cmd}->{arg_spec} }
    );

    require Module::Load;
    Module::Load::load( $cmd );

    if ( @ARGV ) {
        my $subcmd = 'run_'. $ARGV[0];
        if ( $cmd->can( $subcmd ) ) {
            shift @ARGV; 
            return $cmd->$subcmd( $opt, \@ARGV );
        }
    }

    if ( ! $cmd->can('run') ) {
        die "$cmd missing run() method\n";
    }
    return $cmd->run( $opt, $gopt );
}


1;
__END__


=head1 NAME

Your::Command::Dispatch - Dispatcher for Your::Command commands

=head1 SYNOPSIS

  use Your::Command::Dispatch;
  Your::Command::Dispatch->run;

=head1 DESCRIPTION

B<Your::Command::Dispatch> provides option checking, argument checking,
and command dispatching for commands implemented under the Your::Command::* namespace.

This class has a single method:

=over 4

=item run

Dispatch to a L<Your::Command> command based on the contents of @ARGV.

=back

This module was automatically generated by L<App::Dispatcher>(3p).

=head1 SEE ALSO

L<App::Dispatcher>(3p), L<app-dispatcher>(1)

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2011 Mark Lawrence E<lt>nomad@null.netE<gt>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

=cut
