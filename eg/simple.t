use strict;
use warnings;
use PowerTest;

{
    package Foo;
    sub bar { 5963 }
}

describe 'Array' => sub {
    describe '#indexOf()' => sub {
        it 'should return -1 when the value is not present' => sub {
            ok { 1==2 };
            ok { 2==2 };
        };
    };
};

sub foo { 3 }
sub xxx { 'x'x1024 }
ok { 55963 ne Foo->bar() };
ok { 2 ne foo() };
ok { 3 != foo() };
ok { foo() == 2 };
ok { foo() == 3 };
ok { 2 == foo() };
ok { 3 == foo() };
ok { xxx() eq 'y'x100 };

