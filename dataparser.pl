#!/usr/bin/perl
use strict;

use warnings;
use Marpa::R2;
use Data::Dumper;

$\ = "\n";
my $grammar = Marpa::R2::Scanless::G->new({
	#default_action => '::first',
	action_object	=> __PACKAGE__,
	source => \(<<'END_OF_SOURCE'),
:default ::= action => ::array
#:default ::= action => ::rhs
:start ::= Start

Start	::= PathExpr	action => do_arg1
PathExpr ::=
	singlePath		
	| PathExpr '|' singlePath	action => do_pushArgs2array

singlePath ::=	
	step Filter subPath action => do_stepFilterSubpath
	| step Filter action => do_stepFilter
	| step subPath action => do_stepSubpath
	| step	action => do_step

subPath ::= '.' singlePath action => do_arg2

step ::= 
	keyword action => do_keyword
	| INT action => do_digits
	| wildcard action => do_wildcard

Filter ::= 
	'[' Expr ']' action => do_filter
	| '[' Expr ']' Filter action => do_mergeFilters


Expr ::=
	NumericExpr
	||LogicalExpr


NumericExpr ::=
  ArithmeticExpr

 ArithmeticExpr ::=
	'(' NumericExpr ')' 		
	|| NUMBER 													action => do_arg1
	|| FunctionCall 										action => do_arg1
	|| '-' NumericExpr 				
	|| ArithmeticExpr '*' NumericExpr		action => do_operator
	 | ArithmeticExpr '/' NumericExpr		action => do_operator
	 | ArithmeticExpr '%' NumericExpr		action => do_operator
	|| ArithmeticExpr '+' NumericExpr		action => do_operator
	 | ArithmeticExpr '-' NumericExpr		action => do_operator

LogicalExpr ::=
	compareExpr

compareExpr ::=	
	'(' LogicalExpr ')'
	|| PathExpr
	|| FunctionCall 		action => do_arg1
	|| NumericExpr '<' NumericExpr		action => do_operator
	 | NumericExpr '<=' NumericExpr		action => do_operator
	 | NumericExpr '>' NumericExpr		action => do_operator
	 | NumericExpr '>=' NumericExpr		action => do_operator
	|| StringExpr 'lt' StringExpr		action => do_operator
	 | StringExpr 'le' StringExpr		action => do_operator
	 | StringExpr 'gt' StringExpr		action => do_operator
	 | StringExpr 'ge' StringExpr		action => do_operator
	|| NumericExpr '==' NumericExpr		action => do_operator
	 | NumericExpr '!=' NumericExpr		action => do_operator
	 | StringExpr 'eq' StringExpr		action => do_operator
	 | StringExpr 'ne' StringExpr		action => do_operator
	|| compareExpr 'and' LogicalExpr	action => do_operator
	|| compareExpr 'or' LogicalExpr		action => do_operator


StringExpr ::=
	STRING 													action => do_arg1
 	|| FunctionCall 								action => do_arg1
   || StringExpr '||' StringExpr  	action => do_operator


FunctionCall ::=
	FunctionName '(' ArgList ')' action => do_func

FunctionName ::=
	'not'	action => do_arg1 
	| 'name' action => do_arg1
	| 'value' action => do_arg1
	| 'count' action => do_arg1

ArgList ::= Argument* separator => <comma>
# 	EMPTY
# 	|Arguments

# EMPTY ::=

# Arguments ::=
# 	Argument action => do_arg1
# 	| Arguments ',' Argument

Argument ::= Expr action => do_arg1




NUMBER         ~ int
               | int frac
               | int exp
               | int frac exp
 
int            ~ digits
               | '-' digits
               | '+' digits
 
digits         ~ [\d]+
 
frac           ~ '.' digits
 
exp            ~ e digits
 
e              ~ 'e'
               | 'e+'
               | 'e-'
               | 'E'
               | 'E+'
               | 'E-'


INT         ~ int


STRING       ::= lstring               action => do_string
 
lstring        ~ quote in_string quote
quote          ~ ["]
 
in_string      ~ in_string_char*
 
in_string_char  ~ [^"\\]
	| '\' '"'
	| '\' 'b'
	| '\' 'f'
	| '\' 't'
	| '\' 'n'
	| '\' 'r'
	| '\' 'u' four_hex_digits
	| '\' '/'
	| '\\'


four_hex_digits ~ hex_digit hex_digit hex_digit hex_digit
hex_digit       ~ [0-9a-fA-F]

comma          ~ ','

wildcard ~ [*]
keyword ~ [a-zA-Z\N{U+A1}-\N{U+10FFFF}]+

:discard ~ WS
WS ~ [\s]+

END_OF_SOURCE
});

#from http://www.emacswiki.org/emacs/XPath_BNF
my $reader = Marpa::R2::Scanless::R->new(
		{
				grammar => $grammar,
				trace_terminals => 1,
		}
);


sub new { return {}; }

sub do_string {
    shift;
    my $s = $_[0];
 
    $s =~ s/^"//;
    $s =~ s/"$//;
 
    $s =~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/eg;
 
    $s =~ s/\\n/\n/g;
    $s =~ s/\\r/\r/g;
    $s =~ s/\\b/\b/g;
    $s =~ s/\\f/\f/g;
    $s =~ s/\\t/\t/g;
    $s =~ s/\\\\/\\/g;
    $s =~ s{\\/}{/}g;
    $s =~ s{\\"}{"}g;
 
    return $s;
}
sub do_func{
	my $args =	[@_[3..$#_-1]];
	return {func => {$_[1] => $args}}
}
sub do_stringMerge{
	return join '', @_[1..$#_];
}
sub do_operator{
	return {oper => {$_[2] => [$_[1],$_[3]]} };
}
sub do_stepFilterSubpath(){
	my ($step, $filter, $subpath) = @_[1..3];
	warn q|arg is not a hash ref| unless ref $step eq 'HASH'; 
	@{$step}{qw|filter subpath|} = ($filter,$subpath);
	return $step;
}
sub do_stepFilter(){
	my ($step, $filter) = @_[1,2];
	warn q|arg is not a hash ref| unless ref $step eq 'HASH'; 
	$step->{filter} = $filter;
	return $step;
}
sub do_stepSubpath{
	my ($step,$subpath) = @_[1,2];
	warn q|arg is not a hash ref| unless ref $step eq 'HASH'; 
	$step->{subpath} = $subpath;
	return $step;
}
sub do_step{
	my $step = $_[1];
	warn q|arg is not a hash ref| unless ref $step eq 'HASH'; 
	return $step;
}

sub do_arg1{ return $_[1]};
sub do_arg2{ return $_[2]};
sub do_pushArgs2array{
	my ($a,$b) = @_[1,3];
	print Dumper $a;
	print Dumper $b;
	my @array = (@$a,$b);
	return \@array;
}
sub do_filter{ return [$_[2]]};
sub do_mergeFilters{
	my ($filter, $filters) = @_[2,4];
	my @filters = ($filter, @$filters);
	return \@filters; 
}

sub do_keyword{
	my $k = $_[1];
	return {keyword => $k, type => 'keyword'};
}
sub do_digits{
	my $k = $_[1];
	return {digits => $k, type => 'digits'};
}
sub do_wildcard{
	my $k = $_[1];
	return {wildcard => $k, type => 'wildcard'};
}

my $input = shift || <>;
chomp $input;
print "input = $input\n"; 
$reader->read(\$input);
my $root = $reader->value;
print "********root**********";
print Dumper $root;
print "********/root**********";

my $data = {
	a =>{
		b =>{
			c => 3
		}
	}
};
