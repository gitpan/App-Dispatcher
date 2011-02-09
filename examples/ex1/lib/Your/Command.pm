package Your::Command;

sub opt_spec {(
    [ "dry-run|n",     "print out SQL instead of running it" ],
    [ "drop-tables|D", "DROP TABLEs before deploying" ],
)};

sub arg_spec {(
    [ "database=s",   "production|development",
        { default => 'development' } 
    ],
)};

sub run {
    my ($self,$opt) = @_;

    if ( $opt->dry_run ) {
        print "Not ";
    } 
    print "Deploying to ". $opt->database ."\n";
}

1;

