package PowerTest;
use 5.008005;
use strict;
use warnings;
use parent qw(Exporter);

our $VERSION = "0.01";

use B qw(class);
use B::Generate;
use B::Utils qw(walkoptree_simple);
use B::Deparse;
use B::Concise;
use Data::Dumper ();
use constant {
    RESULT_VALUE => 0,
    RESULT_OPINDEX => 1,
};

our @EXPORT = qw(diag ok done_testing);

our $CNT = 0;
our @OP_STACK;
our @TAP_RESULTS;
our $DEPARSE = B::Deparse->new;

sub proclaim {
    my ($cond, $desc) = @_;
    $CNT++;
    print !$cond ? 'not ' : '';
    print "ok $CNT";
    if (defined $desc) {
        print " - $desc";
    }
    print "\n";
}

sub diag {
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

sub null {
    my $op = shift;
    return class($op) eq "NULL";
}

sub done_testing {
    print "1..$CNT\n";
}

sub ok(&) {
    my $code = shift;

    local @TAP_RESULTS;
    local @OP_STACK;

    my $cv= B::svref_2object($code);

    my $root = $cv->ROOT;
    # local $B::overlay = {};
    if (not null $root) {
        my $lineseq = $root->first;
        B::walkoptree($cv->ROOT, 'power_test');
        if (0) {
            {
                my $walker = B::Concise::compile('', '', $code);
                $walker->();
            }
            {
                my $walker = B::Concise::compile('-exec', '', $code);
                $walker->();
            }
        };
        if ($code->()) {
            proclaim(1);
        } else {
            proclaim(0);
            local $Data::Dumper::Terse = 1;
            local $Data::Dumper::Indent = 0;
            for my $result (@TAP_RESULTS) {
                diag($DEPARSE->deparse($OP_STACK[$result->[RESULT_OPINDEX]]));
                diag("   => " . Data::Dumper::Dumper($result->[RESULT_VALUE]));
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
            proclaim($code->());
        } else { # XSUB? (or just a declaration)
            proclaim($code->());
        }
    }
}

sub B::OP::power_test {
    my $self = shift;
    # warn $self->name;
}

sub B::BINOP::power_test {
    my $self = shift;
    if ($self->name eq 'eq') {
        my $target = $self->first;

        my $pushmark = B::OP->new('pushmark', 0);
        my $gv = B::SVOP->new('gv', 0, *tap);
        my $rv2cv = B::UNOP->new('rv2cv', 0, $gv);
        my $list = B::LISTOP->new('list', 0, undef, undef);
        my $entersub = B::UNOP->new(
            'entersub',
            $target->flags, # really?
            undef,
        );
        push @OP_STACK, $target;
        my $target_op_idx = B::SVOP->new('const', 0, 0+@OP_STACK-1);

        # Connect nodes siblings.
        $pushmark->sibling($target);
        $target->sibling($target_op_idx);
        $target_op_idx->sibling($rv2cv);
        $list->first($pushmark);
        $list->last($rv2cv);
        my $n = "$entersub"; # fucking magic stmt. do not remove me.
        $entersub->first($list);
        $entersub->sibling($self->last);

        my $entrypoint = [$self->parent->kids]->[0]->next();

        # Connect nodes next links.
        [$self->parent->kids]->[0]->next($pushmark);
        $pushmark->next($entrypoint);
        $target->next($target_op_idx);
        $target_op_idx->next($gv);
        $gv->next($entersub);
        $entersub->next($self->last);
        $self->first($entersub);

    #   UNOP (0x1ac6b18) entersub [1]
    #       UNOP (0x1ac6b90) null [147]
    #           OP (0x1ac6b58) pushmark
    #           SVOP (0x1ac6c18) const  IV (0x1abbf28) 4
    #           UNOP (0x1ac6bd8) null [17]
    #               SVOP (0x1ac6c58) gv  GV (0x1abbf58) *tap
    }
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

PowerTest - It's new $module

=head1 SYNOPSIS

    use PowerTest;

    t { $a == $b };

=head1 DESCRIPTION

PowerTest is ...

=head1 LICENSE

Copyright (C) tokuhirom.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

tokuhirom E<lt>tokuhirom@gmail.comE<gt>

=cut

