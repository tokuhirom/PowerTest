package PowerTest::Context::TAP;
use strict;
use warnings;
use utf8;
use 5.010_001;

use Term::ANSIColor qw(colored);
use Scope::Guard;

sub new {
    my $class = shift;
    bless {
        count  => 0,
        failed => 0,
    }, $class;
}
sub done { $_[0]->{done} }
sub failed { !!$_[0]->{failed} }

sub proclaim {
    my ($self, $cond, $lineno, $line) = @_;
    $self->{count}++;
    if (!$cond) {
        $self->{failed}++;
        print 'not ';
    }
    print "ok $self->{count}";
    print " - L$lineno";
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
                print STDERR "# $_\n";
            }
        } else {
            print STDERR "# undef\n";
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
    $self->diag(colored(join('/', @{$self->{subtests}}), 'green'));
    return Scope::Guard->new(sub { pop @{$self->{subtests}} });
}

1;

