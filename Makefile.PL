# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Let's eat our own dogfood by bootstrapping and building
# app-dispatcher on the fly
use lib 'lib';
use App::Dispatcher;
use App::Dispatcher::Command;
use Getopt::Long::Descriptive qw/describe_options/;

@ARGV = ();
my ($opt, $usage) = describe_options(
    'fake usage',
    App::Dispatcher::Command->opt_spec,
);

app_dispatcher('App::Dispatcher::Command', $opt);
    
name            'App-Dispatcher';
license         'GPL';
all_from        'lib/App/Dispatcher.pm';
requires        'Template' => 0;
requires        'Pod::Simple' => 0;
requires        'File::ShareDir' => 0;
requires        'Sub::Exporter' => 0;
build_requires  'Test::More' => 0;
install_script  'bin/app-dispatcher';
install_share;
auto_install;
WriteAll;

