use Test2::V0;
use Test2::API;
use PPI;

use App::legacy_postfixderef;

my $app = App::legacy_postfixderef->new;

sub test ($$;$) {
    my ($in, $expected, $desc) = @_;

    my $ctx = Test2::API::context;

    my $doc = PPI::Document->new(\$in);
    is $app->apply($doc), $expected, $desc;

    $ctx->release;
}

subtest 'constructor' => sub {
    test '[]->@*',       '@{[]}';
    test '[0]->@*',      '@{[0]}';
    test '{}->%*',       '%{{}}';
    test '{a => 1}->%*', '%{{a => 1}}';

    test '()->@*', '@{()}', 'list';
};

subtest 'symbol' => sub {
    test '$var->**',  '*$var';
    test '$var->$*',  '$$var';
    test '$var->$#*', '$#$var';
    test '$var->@*',  '@$var';
    test '$var->%*',  '%$var';
    test '$var->&*',  '&$var';

    test '$var[0]->@*',   '@{$var[0]}',   'symbol subscript operator subscript';
    test '$var{a}->%*',   '%{$var{a}}',   'symbol subscript operator subscript';
    test '$var->[0]->@*', '@{$var->[0]}', 'symbol operator subscript';
    test '$var->{a}->%*', '%{$var->{a}}', 'symbol operator subscript';
};

subtest 'method' => sub {
    test 'Class->method->@*',       '@{Class->method}',       'word operator word';
    test '$self->method->@*',       '@{$self->method}',       'symbol operator word';
    test 'Class->method(0)->@*',    '@{Class->method(0)}',    'word operator word list';
    test '$self->method(0)->@*',    '@{$self->method(0)}',    'symbol operator word list';
    test 'keys(Class->method->%*)', 'keys(%{Class->method})', 'word operator word (expression)';
    test 'keys($self->method->%*)', 'keys(%{$self->method})', 'symbol operator word (expression)';
    test 'keys Class->method->%*',  'keys %{Class->method}',  'word operator word (whitespace)';
    test 'keys $self->method->%*',  'keys %{$self->method}',  'symbol operator word (whitespace)';
};

subtest 'word' => sub {
    test 'CONSTANT->@*',   '@{+CONSTANT}',  'word';
    test 'CONSTANT()->@*', '@{CONSTANT()}', 'word list';
    test 'undef->@*',      '@{+undef}',     'word';
};

subtest 'subscript' => sub {
    test '$var->@[0..10]',      '@$var[0..10]';
    test '$var->[0]->@[0..10]', '@{$var->[0]}[0..10]';
    test '$var->@{qw/a b c/}',  '@$var{qw/a b c/}';
    test '$var->%[0..10]',      '%$var[0..10]';
    test '$var->%{qw/a b c/}',  '%$var{qw/a b c/}';
    test '$var->*{SCALAR}',     '*$var{SCALAR}';
};

subtest 'complex' => sub {
    test '($var->@*)[0]->@*', '@{(@$var)[0]}', 'symbol and subscript';
    test '$var->@{a}->@*',    '@{@$var{a}}',   'symbol operator and cast subscript';
    test '$var->@*; $var->%*;', '@$var; %$var;';
    test '$var->{a}->%* = ();', '%{$var->{a}} = ();';
};

done_testing;
