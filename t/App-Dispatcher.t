use strict;
use warnings;
use Test::More;
use Test::Script::Run qw/:all/;
use App::Dispatcher;
use App::Dispatcher::Dispatcher;
use lib 't/lib';

{
    no warnings 'once';
    @Test::Script::Run::BINDIRS = ( 'bin', 't/bin' );
}

# Just check that Makefile.PL did its stuff.
can_ok( 'App::Dispatcher',             'app_dispatcher' );
can_ok( 'App::Dispatcher::Dispatcher', 'run' );

# Now check app-dispatcher

# save some typing
my $app = 'app-dispatcher';
my ( $return, $stdout, $stderr );

( $return, $stdout, $stderr ) = run_script($app);
like last_script_stderr, qr/^usage:/, 'usage';

#TODO: {
#    local $TODO = 'Test::Script::Run not returning correctly';
#    is $return, 2, 'usage exit value';
#}

( $return, $stdout, $stderr ) = run_script( $app, [qw/--help/] );
like last_script_stdout,  qr/^usage:/, 'help usage';
is last_script_exit_code, 1,           'help exit code';

run_output_matches(
    $app,
    [qw/--add-debug --add-help App::Dispatcher/],
    ['Generating lib/App/Dispatcher/Dispatcher.pm'],
    [], 'generating'
);

#is last_script_exit_code, 0, 'generate exit value';

chdir 't' || die "chdir: $!";
unlink('lib/Your/Command/Dispatcher.pm');
open( TMP, '>', 'lib/Your/Command/Dispatcher.pm' ) || die "open:$!";
print TMP '';
close TMP;

run_output_matches(
    $app,
    [qw/--add-debug --add-help Your::Command/],
    ['Generating lib/Your/Command/Dispatcher.pm'],
    ['lib/Your/Command/Dispatcher.pm is writable! (use -f to overwrite)'],
    'generating your command'
);

#is last_script_exit_code, 2, 'generate exit value';

run_output_matches(
    $app,
    [qw/--add-debug --add-help -f Your::Command/],
    ['Generating lib/Your/Command/Dispatcher.pm'],
    [], 'generating your command with force'
);

run_output_matches(
    $app,
    [qw/--add-debug --add-help -f Your::Command/],
    ['Generating lib/Your/Command/Dispatcher.pm'],
    [], 'generating your command with force'
);

$app = 'ex';

( $return, $stdout, $stderr ) = run_script($app);
like last_script_stderr, qr/^usage:/, 'stderr usage';

( $return, $stdout, $stderr ) = run_script( $app, [qw/--help/] );
like last_script_stdout,  qr/^usage:/, 'stdout usage';
is last_script_exit_code, 1,           'help exit code';

( $return, $stdout, $stderr ) = run_script( $app, [qw/--help junk/] );
like last_script_stdout,  qr/^usage:/, 'stdout usage with help and bad arg';
is last_script_exit_code, 1,           'help exit code';

( $return, $stdout, $stderr ) = run_script( $app, [qw/junk/] );
like last_script_stderr, qr/^usage:/, 'stderr usage with bad arg';

( $return, $stdout, $stderr ) = run_script( $app, [qw/--help deploy/] );
like last_script_stdout,  qr/^usage:/, 'stdout usage with help and good arg';
is last_script_exit_code, 1,           'help exit code';

( $return, $stdout, $stderr ) = run_script( $app, [qw/deploy/] );
like last_script_stderr, qr/^usage: ex deploy \[options\] <database>/,
  'missing mandatory arg ';

( $return, $stdout, $stderr ) = run_script( $app, [qw/deploy --help/] );
like last_script_stdout, qr/^usage: ex deploy \[options\] <database>/,
  'help wih good command';

run_output_matches( $app, [qw/deploy prod/], ['Deploying to prod'], [],
    'run ok' );

run_output_matches( $app, [qw/-n deploy prod/], ['Not Deploying to prod'], [],
    'run with global opt ok' );

( $return, $stdout, $stderr ) = run_script( $app, [qw/deploy prod --help/] );
like last_script_stdout, qr/^usage: ex deploy \[options\] <database>/,
  'help wih good command + arg';

done_testing();
