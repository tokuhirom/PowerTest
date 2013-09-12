use strict;
use warnings;
use utf8;
use Test::More;

local $ENV{POWER_TEST_CONTEXT} = 'PowerTest::Context::TAP';
{
    open my $fh, '>', \my $out
        or die $!;
    {
        local *STDOUT = $fh;
        local *STDERR = $fh;
        eval <<'...';
package Sandbox;
use PowerTest;
$PowerTest::TESTING_ITSELF++;

sub foo { 3 }
ok { foo() == 2 };
ok { foo() == 3 };
done_testing;
...
    }
    ok(!$@) or diag $@;
    is($out, <<'...');
not ok 1 - L6
# Sandbox::foo()
#    => 3
ok 2 - L7
1..2
...
    diag $out;
}

done_testing;

