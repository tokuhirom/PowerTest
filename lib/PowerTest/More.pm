package PowerTest::More;
use strict;
use warnings;
use utf8;
use 5.010_001;
use Test::More;
use B::Deparse;
use Data::Dumper ();
use Text::Truncate qw(truncstr);
use parent qw(Exporter);

use PowerTest::Core;
use PowerTest::FromLine;

our @EXPORT = (qw(expect), @Test::More::EXPORT);

use constant {
    RESULT_VALUE => 0,
    RESULT_OPINDEX => 1,
};

our $DEPARSE = B::Deparse->new;
our $DUMP_CUTOFF = 80;

sub expect(&) {
    my ($code) = @_;

    my ($package, $filename, $line_no, $line) = PowerTest::FromLine::inspect_line(0);

    my $CONTEXT = Test::More->builder;

    local $@;
    my ($retval, $err, $tap_results, $op_stack)
        = PowerTest::Core->give_me_power($code);
    my $description = "L$line_no" . (length($line) ? " : $line" : '');
    if ($retval) {
        $CONTEXT->ok(1, $description);
    } else {
        $CONTEXT->ok(0, $description);
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

