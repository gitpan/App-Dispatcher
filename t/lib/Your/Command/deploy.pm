package Your::Command::deploy;

sub order { 1 }

sub opt_spec {
    [ 'full', 'run a full deployment' ],;
}

sub arg_spec {
    (
        [
            "database=s",
            "production|development",
            { default => 'development', required => 1 }
        ],
    );
}

sub run {
    my ( $self, $opt ) = @_;

    if ( $opt->dry_run ) {
        print "Not ";
    }
    print "Deploying to " . $opt->database . "\n";
}

1;
__END__

=head1 NAME

Your::Command::deploy - deploy to a database

