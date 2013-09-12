use strict;
use Test::More;

package Foo;
::use_ok $_ for qw(
    PowerTest
);

$PowerTest::TESTING_ITSELF++;

::done_testing;

