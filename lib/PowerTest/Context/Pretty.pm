package PowerTest::Context::Pretty;
use strict;
use warnings;
use utf8;
use 5.010_001;

use Scope::Guard;
use Term::ANSIColor qw(colored);
use Term::Encoding;

my $TERM_ENCODING = Term::Encoding::term_encoding();
my $ENCODING_IS_UTF8 = $TERM_ENCODING =~ /^utf-?8$/i;

binmode *STDOUT, "encoding($TERM_ENCODING)";
binmode *STDERR, "encoding($TERM_ENCODING)";

sub new {
    my $class = shift;
    bless {
        count  => 0,
        failed => 0,
        indent_level => 2,
        subtests => [],
    }, $class;
}
sub done { $_[0]->{done} }
sub failed { !!$_[0]->{failed} }
sub indent {
    my ($self, $i) = @_;
    $i ||= 0;
    ' ' x (0+(@{$self->{subtests}}+$i)*$self->{indent_level})
}

sub proclaim {
    my ($self, $cond, $lineno, $line) = @_;
    $self->{count}++;
    print $self->indent;
    if ($cond) {
        print colored("\x{2713} ", 'green');
    } else {
        $self->{failed}++;
        print colored("\x{2716} ", 'red');
    }
    print " L$lineno";
    if (length($line) > 0) {
        print ": $line";
    }
    print "\n";
}

sub diag {
    my $self = shift;

    for (@_) {
        if (defined $_) {
            for (split /\n/, $_) {
                print STDERR $self->indent(1) . colored($_, 'cyan') . "\n";
            }
        } else {
            print STDERR "undef\n";
        }
    }
}

sub done_testing {
    my $self = shift;
    $self->{done}++;
    print "1..$self->{count}\n";
}

sub push_subtest {
    my ($self, $title) = @_;
    push @{$self->{subtests}}, $title;
    print $self->indent(-1) . colored($title, 'yellow') . "\n";
    return Scope::Guard->new(sub { pop @{$self->{subtests}} });
}

1;

