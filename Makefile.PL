# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Let's eat our own dogfood by bootstrapping and building
# app-dispatcher on the fly
use lib 'lib';
use App::Dispatcher qw/app_dispatcher/;
use Getopt::Long::Descriptive qw/describe_options/;

my @OLDARGV = @ARGV;
@ARGV = ();

my ($opt, $usage) = describe_options(
    'fake usage',
    App::Dispatcher->opt_spec,
);

@ARGV = @OLDARGV;

app_dispatcher('App::Dispatcher', $opt);

name                'App-Dispatcher';
license             'GPL';
all_from            'lib/App/Dispatcher.pm';

requires            'Template' => 0;
requires            'File::ShareDir' => 0;
requires            'Sub::Exporter' => 0;
requires            'Getopt::Long::Descriptive' => 0;

configure_requires  'Template' => 0;
configure_requires  'File::ShareDir' => 0;
configure_requires  'Sub::Exporter' => 0;
configure_requires  'Getopt::Long::Descriptive' => 0;

test_requires       'Test::More' => 0;

install_script      'bin/app-dispatcher';
install_share;
auto_install;

WriteAll;
