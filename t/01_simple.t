use strict;
use warnings;
use utf8;
use Test::More;
use Capture::Tiny;

{
    open my $fh, '>', \my $out;
    {
        local *STDOUT = $fh;
        local *STDERR = $fh;
        eval <<'...';
package Sandbox;
use PowerTest;

sub foo { 3 }
ok { foo() == 2 };
ok { foo() == 3 };
done_testing;
...
    }
    ok(!$@) or diag $@;
    is($out, <<'...');
not ok 1
# Sandbox::foo()
#    => 3
ok 2
1..2
...
    diag $out;
}

done_testing;

