use strict;
use warnings;

use inc::Module::Install;

name            'Log-Smart';
all_from        'lib/Log/Smart.pm';

requires        'YAML'               => 0;
build_requires  'Test::More'         => 0;


auto_install;
WriteAll;
