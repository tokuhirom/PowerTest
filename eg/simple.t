use strict;
use warnings;
use PowerTest;

{
    package Foo;
    sub bar { 5963 }
}

sub foo { 3 }
ok { 55963 ne Foo->bar() };
ok { 2 ne foo() };
ok { 3 != foo() };
ok { foo() == 2 };
ok { foo() == 3 };
ok { 2 == foo() };
ok { 3 == foo() };
done_testing;
