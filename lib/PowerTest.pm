package PowerTest;
use 5.008005;
use strict;
use warnings;
use parent qw(Exporter);

our $VERSION = "0.01";

use B::Deparse;
use Cwd ();
use File::Spec;
use Data::Dumper ();
use List::Util ();
use Text::Truncate qw(truncstr);
use Module::Load ();

use constant {
    RESULT_VALUE => 0,
    RESULT_OPINDEX => 1,
};

use PowerTest::Core;


our @EXPORT = qw(diag ok done_testing describe context it);



our $DEPARSE = B::Deparse->new;
our $CONTEXT = do {
    my $context = $ENV{POWER_TEST_CONTEXT} || 'PowerTest::Context::Pretty';
    unless ($context->can('new')) {
        Module::Load::load($context);
    }
    $context->new();
};
our @DESCRIBE;
our $IN_ENDING = 0;
our $DUMP_CUTOFF = 80;

our $TESTING_ITSELF;

END {
    $IN_ENDING = 1;

    unless ($TESTING_ITSELF) {
        if ($ENV{POWER_TEST_SHUFFLE}) {
            @DESCRIBE = List::Util::shuffle(@DESCRIBE);
        }

        while (my ($title, $code) = splice @DESCRIBE, 0, 2) {
            my $guard = $CONTEXT->push_subtest($title);
            $code->();
        }
        unless ($CONTEXT->done) {
            $CONTEXT->done_testing;
        }
        if ($CONTEXT->failed) {
            $? = 1;
        }
    }
}

sub describe {
    my ($title, $code) = @_;
    if ($IN_ENDING) {
        my $guard = $CONTEXT->push_subtest($title);
        $code->();
    } else {
        push @DESCRIBE, $title, $code;
    }
}

sub context {
    my ($title, $code) = @_;
    my $guard = $CONTEXT->push_subtest($title);
    $code->();
}

sub it {
    my ($title, $code) = @_;
    my $guard = $CONTEXT->push_subtest($title);
    $code->();
}

sub diag { $CONTEXT->diag(@_) }
sub done_testing { $CONTEXT->done_testing }

our %FH_CACHE;

our $BASE_DIR = Cwd::getcwd();
our %FILECACHE;

sub ok(&) {
    my $code = shift;

    # TODO: support method call

   my ($package, $filename, $line_no) = caller(0);
   my $line = sub {
       undef $filename if $filename eq '-e';
       if (defined $filename) {
           $filename = File::Spec->rel2abs($filename, $BASE_DIR);
           my $file = $FILECACHE{$filename} ||= [
               do {
                   # Do not die if we can't open the file
                   open my $fh, '<', $filename
                       or return '';
                   <$fh>
               }
           ];
           my $line = $file->[ $line_no - 1 ];
           $line =~ s{^\s+|\s+$}{}g;
           $line;
       } else {
           "";
       }
   }->();

    local $@;
    my ($retval, $err, $tap_results, $op_stack)
        = PowerTest::Core->give_me_power($code);
    if ($retval) {
        $CONTEXT->proclaim(1, $line_no, $line);
    } else {
        $CONTEXT->proclaim(0, $line_no, $line);
        $CONTEXT->diag($err) if $err;
        local $Data::Dumper::Terse = 1;
        local $Data::Dumper::Indent = 0;
        for my $result (@$tap_results) {
            $CONTEXT->diag($DEPARSE->deparse($op_stack->[$result->[RESULT_OPINDEX]]));
            $CONTEXT->diag("   => " . truncstr(Data::Dumper::Dumper($result->[RESULT_VALUE]), $DUMP_CUTOFF, '...'));
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

PowerTest - With great power, comes great responsibility.

=head1 SYNOPSIS

    use PowerTest;

    describe 'MyClass' => sub {
        describe '#foo' => sub {
            ok { MyClass->foo() == 3 };
        }
    };

=head1 DESCRIPTION

B<WARNINGS: This module is currently ALPHA state. Any APIs will change without notice. And this module uses the B power, it may cause segmentation fault.>

PowerTest is yet another testing framework.

=head1 LICENSE

Copyright (C) tokuhirom.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

tokuhirom E<lt>tokuhirom@gmail.comE<gt>

=cut

