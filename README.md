# NAME

PowerTest - With great power, comes great responsibility.

# SYNOPSIS

    use PowerTest;

    describe 'MyClass' => sub {
        describe '#foo' => sub {
            ok { MyClass->foo() == 3 };
        }
    };

# DESCRIPTION

__WARNINGS: This module is currently ALPHA state. Any APIs will change without notice. And this module uses the B power, it may cause segmentation fault.__

PowerTest is yet another testing framework.

PowerTest shows progress data if it's failes. For example, here is a testing script using PowerTest. This test may fail.

    use PowerTest;

    sub foo { 3 }
    ok { foo() == 2 };

Output is:

    not ok 1 - L6: ok { foo() == 2 };
    # foo()
    #    => 3
    1..1

Woooooooh! It's pretty magical. PowerTest.pm shows the calcuration progress! You don't need to use different functions for testing types, like ok, cmp\_ok, is...

# LICENSE

Copyright (C) tokuhirom.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

tokuhirom <tokuhirom@gmail.com>
