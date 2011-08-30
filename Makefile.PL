# Load the Module::Install bundled in ./inc/
use inc::Module::Install;

# Eat our own dogfood by bootstrapping and building app-dispatcher on
# the fly
use lib 'lib';
use App::Dispatcher qw/run_app_dispatcher/;
run_app_dispatcher(qw/App::Dispatcher --add-help/);

# Now normal Makefile.PL stuff

name 'App-Dispatcher';
license 'GPL';
all_from 'lib/App/Dispatcher.pm';

requires 'Storable'                  => 0;
requires 'Template'                  => 0;
requires 'File::ShareDir'            => 0;
requires 'File::Basename'            => 0;
requires 'Sub::Exporter'             => 0;
requires 'Getopt::Long::Descriptive' => 0;
requires 'Perl::Tidy'                => 0;
requires 'Pod::Tidy'                 => 0;
requires 'File::Slurp'               => 0;

configure_requires 'Storable'                  => 0;
configure_requires 'Template'                  => 0;
configure_requires 'File::ShareDir'            => 0;
configure_requires 'File::Basename'            => 0;
configure_requires 'Sub::Exporter'             => 0;
configure_requires 'Getopt::Long::Descriptive' => 0;
configure_requires 'Perl::Tidy'                => 0;
configure_requires 'Pod::Tidy'                 => 0;
configure_requires 'File::Slurp'               => 0;

test_requires 'Test::More'        => 0;
test_requires 'Test::Script::Run' => '0.05';

install_script 'bin/app-dispatcher';
install_share;
auto_install;

repository 'git://github.com/mlawren/app-dispatcher.git';

WriteAll;
