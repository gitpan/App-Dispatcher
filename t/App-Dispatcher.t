use Test::More;
use strict;
use warnings;

# Just check that Makefile.PL did its stuff.
use_ok('App::Dispatcher::Dispatcher');
can_ok('App::Dispatcher::Dispatcher', 'run');

done_testing();
