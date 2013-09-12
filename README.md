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

# LICENSE

Copyright (C) tokuhirom.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

tokuhirom <tokuhirom@gmail.com>
