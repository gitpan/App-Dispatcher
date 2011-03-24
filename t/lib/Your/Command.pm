package Your::Command;

sub require_order { 1 }

sub opt_spec {
    ( [ "dry-run|n", "print out SQL instead of running it" ], );
}

sub arg_spec {
    ( [ "command=s", "what to do", { required => 1 } ], );
}

1;

