package PowerTest;
use 5.008005;
use strict;
use warnings;
use parent qw(Exporter);

our $VERSION = "0.01";

use B qw(class);
use B::Generate;
use B::Deparse;
use B::Concise;
use Cwd ();
use File::Spec;
use Data::Dumper ();
use B::Utils qw(walkoptree_simple);
use Scope::Guard;
use List::Util ();
use Text::Truncate qw(truncstr);
use Module::Load ();
use constant {
    RESULT_VALUE => 0,
    RESULT_OPINDEX => 1,
};

our @EXPORT = qw(diag ok done_testing describe context it);

{
    package PowerTest::Context::Pretty;
    use Term::ANSIColor qw(colored);
    use Term::Encoding;

    my $TERM_ENCODING = Term::Encoding::term_encoding();
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
}

{
    package PowerTest::Context::TAP;
    use Term::ANSIColor qw(colored);

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
}

our @OP_STACK;
our @TAP_RESULTS;
our $ROOT;
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

END {
    $IN_ENDING = 1;
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

sub null {
    my $op = shift;
    return class($op) eq "NULL";
}

our %FH_CACHE;

our $BASE_DIR = Cwd::getcwd();
our %FILECACHE;

sub ok(&) {
    my $code = shift;

    my $cv= B::svref_2object($code);

    local @TAP_RESULTS;
    local @OP_STACK;
    local $ROOT = $cv->ROOT;

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

    my $root = $cv->ROOT;
    # local $B::overlay = {};
    if (not null $root) {
        my $lineseq = $root->first;
      # for my $node ($cv->ROOT->descendants) {
      #     if (class($node) eq 'BINOP') {
      #         B::BINOP::power_test($node);
      #     }
      # }
        B::walkoptree($cv->ROOT, 'power_test');
        if (0) {
            {
                my $walker = B::Concise::compile('', '', $code);
                $walker->();
            }
        };
        local $@;
        if (eval { $code->() }) {
            $CONTEXT->proclaim(1, $line_no, $line);
        } else {
            $CONTEXT->proclaim(0, $line_no, $line);
            $CONTEXT->diag($@) if $@;
            local $Data::Dumper::Terse = 1;
            local $Data::Dumper::Indent = 0;
            for my $result (@TAP_RESULTS) {
                $CONTEXT->diag($DEPARSE->deparse($OP_STACK[$result->[RESULT_OPINDEX]]));
                $CONTEXT->diag("   => " . truncstr(Data::Dumper::Dumper($result->[RESULT_VALUE]), $DUMP_CUTOFF, '...'));
            }
        }
        if (0) {
            eval {
                warn B::Deparse->new->coderef2text($code);
            };
            warn $@ if $@;
        }
    }
    else {
        my $sv = $cv->const_sv;
        if ($$sv) {
            # uh-oh. inlinable sub... format it differently
            proclaim($code->(), $line_no, $line);
        } else { # XSUB? (or just a declaration)
            proclaim($code->(), $line_no, $line);
        }
    }
}

sub B::OP::power_test {
    my $self = shift;
    # warn $self->name;
}

sub find_prev {
    my ($root, $op) = @_;
    printf "Finding $$op @{[ $op->name ]}\n";
    for my $e ($root->descendants) {
        printf("  next: %s %d\n", $e->next->name, ${$e->next});
        if ($$op == ${$e->next}) {
            return $e;
        }
    }
}

sub B::BINOP::power_test {
    my $self = shift;
    my %supported_ops = (
        map { $_ => 1 }
        qw(
         eq  ne  gt  ge  lt  le
        seq sne sgt sge slt sle)
    );
    if ($supported_ops{$self->name}) {
        if ($self->first->name ne 'const') {
            my $entersub = wrap_by_tap(
                $self->first,
                [$self->parent->kids]->[0]->next(),
                sub {
                    [$self->parent->kids]->[0]->next(@_);
                }
            );
            $entersub->next($self->last);
            $entersub->sibling($self->last);
            $self->first($entersub);
        }
        if ($self->last->name ne 'const') {
            my $nnext = $self->last->next;
            my $entersub = wrap_by_tap(
                $self->last,
                $self->first->next,
                sub {
                    $self->first->next(@_),
                }
            );
            $self->first->sibling($entersub);
            $entersub->next($nnext);
            $self->last($entersub);
        }

    #   UNOP (0x1ac6b18) entersub [1]
    #       UNOP (0x1ac6b90) null [147]
    #           OP (0x1ac6b58) pushmark
    #           SVOP (0x1ac6c18) const  IV (0x1abbf28) 4
    #           UNOP (0x1ac6bd8) null [17]
    #               SVOP (0x1ac6c58) gv  GV (0x1abbf58) *tap
    }
}

sub wrap_by_tap {
    my ($target, $entrypoint, $set_entrypoint) = @_;

    my $pushmark = B::OP->new('pushmark', 0);
    $pushmark->sibling($target);

    my $gv = B::SVOP->new('gv', 0, *tap);
    my $rv2cv = B::UNOP->new('rv2cv', 0, $gv);
    my $list = B::LISTOP->new('list', 0, $pushmark, $rv2cv);

    push @OP_STACK, $target;
    my $target_op_idx = B::SVOP->new('const', 0, 0+@OP_STACK-1);
    $target->sibling($target_op_idx);
    $target_op_idx->sibling($rv2cv);

    my $entersub = B::UNOP->new(
        'entersub',
        $target->flags, # really?
        $list,
    );

    # Connect nodes next links.
    $set_entrypoint->($pushmark);
    $pushmark->next($entrypoint);
    $target->next($target_op_idx);
    $target_op_idx->next($gv);
    $gv->next($entersub);

    return $entersub;
}

sub tap {
    my ($stuff, $target_op_idx) = @_;
    push @TAP_RESULTS, [
        $stuff,
        $target_op_idx,
    ];
    return $stuff;
}

1;
__END__

=encoding utf-8

=head1 NAME

PowerTest - With great power, comes great responsibility.

=head1 SYNOPSIS

    use PowerTest;

    ok { $a == $b };

=head1 DESCRIPTION

PowerTest is ...

=head1 LICENSE

Copyright (C) tokuhirom.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

tokuhirom E<lt>tokuhirom@gmail.comE<gt>

=cut

