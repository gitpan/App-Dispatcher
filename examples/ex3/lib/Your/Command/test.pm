package Your::Command::test;

sub arg_spec {(
    [ "database=s",   "production|development",
        { default => 'development', required => 1 } 
    ],
)};

sub run {
    my ($self,$opt,$gopt) = @_;

    if ( $gopt->dry_run ) {
        print "Not ";
    } 
    print "Testing with ". $opt->database ."\n";
}

1;
__END__

=head1 NAME

Your::Command::test - test a database


