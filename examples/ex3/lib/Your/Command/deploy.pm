package Your::Command::deploy;

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
    my ( $self, $opt, $gopt ) = @_;

    if ( $gopt->dry_run ) {
        print "Not ";
    }
    print "Deploying to " . $opt->database . "\n";
}

1;
__END__

=head1 NAME

Your::Command::deploy - deploy to a database

