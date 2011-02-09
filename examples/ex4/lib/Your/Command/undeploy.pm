package Your::Command::undeploy;

sub order {3};

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
    print "Undeploying ". $opt->database ."\n";
}


1;
__END__

=head1 NAME

Your::Command::undeploy - undeploy a database

