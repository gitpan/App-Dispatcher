use strict;
use warnings;
use Test::More;
use Test::Script::Run qw/:all/;
use App::Dispatcher qw/run_app_dispatcher/;
use lib 't/lib';

# rebuild now to avoid mtime warnings when I 'git reset' things
BEGIN {
    run_app_dispatcher(qw/App::Dispatcher --add-help/);
}

use App::Dispatcher::Dispatcher;
can_ok( 'App::Dispatcher::Dispatcher', 'run' );

{
    no warnings 'once';
    @Test::Script::Run::BINDIRS = ( 'bin', 't/bin' );
}

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
like last_script_stdout, qr/^usage:/, 'help usage';
ok !last_script_exit_code, 'help exit code';

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
like last_script_stdout, qr/^usage:/, 'stdout usage';
ok !last_script_exit_code, 'help exit code';

( $return, $stdout, $stderr ) = run_script( $app, [qw/--help junk/] );
like last_script_stdout, qr/^usage:/, 'stdout usage with help and bad arg';
ok !last_script_exit_code, 'help exit code';

( $return, $stdout, $stderr ) = run_script( $app, [qw/junk/] );
like last_script_stderr, qr/^usage:/, 'stderr usage with bad arg';

( $return, $stdout, $stderr ) = run_script( $app, [qw/--help deploy/] );
like last_script_stdout, qr/^usage:/, 'stdout usage with help and good arg';
ok !last_script_exit_code, 'help exit code';

( $return, $stdout, $stderr ) = run_script( $app, [qw/deploy/] );
like last_script_stderr, qr/^usage: ex deploy \[options\] DATABASE/,
  'missing mandatory arg ';

( $return, $stdout, $stderr ) = run_script( $app, [qw/deploy --help/] );
like last_script_stdout, qr/^usage: ex deploy \[options\] DATABASE/,
  'help wih good command';

run_output_matches( $app, [qw/deploy prod/], ['Deploying to prod'], [],
    'run ok' );
ok !last_script_exit_code, 'deploy exit code';

run_output_matches( $app, [qw/deploy -n prod/], ['Not Deploying to prod'], [],
    'run with global opt ok' );
ok !last_script_exit_code, 'not deploy exit code';

( $return, $stdout, $stderr ) = run_script( $app, [qw/deploy prod --help/] );
like last_script_stdout, qr/^usage: ex deploy \[options\] DATABASE/,
  'help wih good command + arg';

done_testing();
