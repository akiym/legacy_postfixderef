package App::legacy_postfixderef;
use strict;
use warnings;
use PPI;

our $VERSION = "0.01";

sub new { bless {}, shift }

sub run {
    my ($self, @argv) = @_;

    my $code = do { local $/; <STDIN> };
    my $doc = PPI::Document->new(\$code);

    print $self->apply($doc);

    return 0;
}

sub apply {
    my ($self, $doc) = @_;

    my $casts = $doc->find(sub {
        my $t = $_[1];
        $t->isa('PPI::Statement')
    });
    $casts ||= [];

    for my $cast (@$casts) {
        my @replace;
      REDO_REPLACE:
        my @tokens = $cast->children;
        for (my $i = 0; $i < @tokens - 1; $i++) {
            my ($a, $b, $c) = @tokens[$i, $i+1, $i+2];
            if ($a->isa('PPI::Token::Operator') && $a->content eq '->' &&
                $b->isa('PPI::Token::Cast')) {
                if ($b->content =~ /^(?:[*\$@%&]|\$\#)\*$/ ||
                    ($b->content =~ /^[*@%]$/ &&
                        $c && $c->isa('PPI::Structure::Subscript'))) {
                } else {
                    next;
                }

                $cast->remove_child($a);
                $cast->remove_child($b);
                $cast->remove_child($_) for @replace;

                my @back_tokens = @tokens[$i+2..$#tokens];
                $cast->remove_child($_) for @back_tokens;

                my ($cast_type) = $b->content =~ /^(.+?)\*?$/;
                $self->_replace_cast($cast, $cast_type, @replace);

                $cast->add_element($_) for @back_tokens;

                @replace = ();
                goto REDO_REPLACE;
            } elsif ($a->isa('PPI::Token::Whitespace')) {
                # keys Class->method->%* ==> keys %{Class->method->%*}
                @replace = ();
            } else {
                push @replace, $a;
            }
        }
    }

    return $doc->serialize;
}

sub _replace_cast {
    my ($self, $cast, $cast_type, @replace) = @_;

    if (@replace == 1 && $replace[0]->isa('PPI::Token::Symbol')) {
        # $var->@* ==> @$var
        $cast->add_element(PPI::Token::Cast->new($cast_type));
        $cast->add_element($replace[0]);
    } else {
        my $block = PPI::Structure::Block->new(PPI::Token::Structure->new('{'));
        $block->{finish} = PPI::Token::Structure->new('}');
        if (@replace == 1 && $replace[0]->isa('PPI::Token::Word')) {
            # CONSTANT->@* ==> @{+CONSTANT}
            $block->add_element(PPI::Token::Operator->new('+'));
            $block->add_element($replace[0]);
        } else {
            # $var->[0]->@* ==> @{$var->[0]}
            $block->add_element($_) for @replace;
        }
        $cast->add_element(PPI::Token::Cast->new($cast_type));
        $cast->add_element($block);
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

App::legacy_postfixderef - Convert postfix dereference to usual dereference for legacy Perls

=head1 SYNOPSIS

    $ cat Foo.pm | legacy_postfixderef

=head1 DESCRIPTION

App::legacy_postfixderef is ...

=head1 LICENSE

Copyright (C) Takumi Akiyama.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Takumi Akiyama E<lt>t.akiym@gmail.comE<gt>

=cut