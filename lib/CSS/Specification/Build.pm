#!/usr/bin/env perl6

#= translates w3c property definitions to basic Perl 6 roles, grammars or actions.

module CSS::Specification::Build;

use CSS::Specification;
use CSS::Specification::Actions;

#= generate parsing grammar
our proto sub generate(Str $type, Str $name, Str :$input-spec?, Bool :$proforma?) { * };
multi sub generate('grammar', Str $grammar-name, Str :$input-spec?, Bool :$proforma?) {

    my $actions = CSS::Specification::Actions.new;
    my @defs = load-props($input-spec, $actions);

    say "use v6;";
    say "#  -- DO NOT EDIT --";
    say "# generated by: $*PROGRAM_NAME {@*ARGS}";
    say "";
    say "grammar {$grammar-name} \{";

    generate-perl6-rules(@defs, :$proforma);

    say '}';
}

#= generate actions class
multi sub generate('actions', Str $class-name, Str :$input-spec?) {

    my $actions = CSS::Specification::Actions.new;
    my @defs = load-props($input-spec, $actions);

    say "use v6;";
    say "#  -- DO NOT EDIT --";
    say "# generated by: $*PROGRAM_NAME {@*ARGS}";
    say "";
    say "class {$class-name} \{";

    my %prop-refs = $actions.prop-refs;
    generate-perl6-actions(@defs, %prop-refs);

    say '}';
}

#= generate interface roles.
multi sub generate('interface', Str $role-name, Str :$input-spec?) {

    my $actions = CSS::Specification::Actions.new;
    my @defs = load-props($input-spec, $actions);

    say "use v6;";
    say "#  -- DO NOT EDIT --";
    say "# generated by: $*PROGRAM_NAME {@*ARGS}";

    say "role {$role-name} \{";

    my %prop-refs = $actions.prop-refs;
    my %prop-names = $actions.props;
    generate-perl6-interface(@defs, %prop-refs, %prop-names);

    say '}';
}

sub load-props ($properties-spec, $actions?) {
    my $fh = $properties-spec
        ?? open $properties-spec, :r
        !! $*IN;

    my @props;

    for $fh.lines -> $prop-spec {
        # handle full line comments
        next if $prop-spec ~~ /^'#'/ || $prop-spec eq '';
        # '| inherit' and '| initial' are implied anyway; get rid of them
        my $spec = $prop-spec.subst(/\s* '|' \s* [inherit|initial]/, ''):g;

        my $/ = CSS::Specification.subparse($spec, :rule('property-spec'), :actions($actions) );
        die "unable to parse: $prop-spec"
            unless $/.ast;
        my $prop-defn = $/.ast;

	@props.push: $prop-defn;
    }

    return @props;
}

sub generate-perl6-rules(@defs, :$proforma) {

    my %seen;

    my $proforma-str = $proforma ?? '<proforma> || ' !! '';

    for @defs -> $def {

        my @props = @( $def<props> );
        my $perl6 = $def<perl6>;
        my $synopsis = $def<synopsis>;

        # boxed repeating property. repeat the expr
        my $boxed = $synopsis ~~ / '{1,4}' $/
            ?? '$<boxed>='
            !! '';
        my $repeats = '';
        if $boxed {
            $perl6 ~~ s/('**1..4') $//;
            $repeats = '**1..4';
        }

        for @props -> $prop {
            next if %seen{$prop}++;
            my $match = $prop.subst(/\-/, '\-'):g;

            say "    #| $prop: $synopsis";
            say "    rule decl:sym<{$prop}> \{:i ($match) ':'  {$boxed}[ {$proforma-str}<expr=.expr-{$prop}>$repeats || <usage(&?ROUTINE.WHY)> ] \}";
            say "    rule expr-$prop \{:i $perl6 \}";
        }
    }
}

sub generate-perl6-actions(@defs, %references) {

    my %seen;

    for @defs -> $def {

        my @props = @( $def<props> );
        my $synopsis = $def<synopsis>;

        # automagical detection of 'boxed' properties, eg: margin: [ <length> | <percentage> | auto ]{1,4} 
        my $boxed = $synopsis ~~ / '{1,4}' $/;

        for @props -> $prop {
            next if %seen{$prop}++;

            say "    method expr-{$prop}(\$/) \{ make \$.list(\$/) \}"
                if %references{'expr-' ~ $prop}:exists;
        }
    }
}


#= generate an interface class for all unresolved terms.
sub generate-perl6-interface(@defs, %references, %prop-names) {

    my %unresolved = %references;
    %unresolved{'expr-' ~ $_}:delete
        for %prop-names.keys;

    for %unresolved.keys.sort -> $sym {
        say "    method {$sym}(\$/) \{ ... \}";
    }
}