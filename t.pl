#!/usr/bin/perl
use strict;

use warnings;
use Marpa::R2;
use Data::Dumper;

$\ = "\n";
my $grammar = Marpa::R2::Scanless::G->new(
    {
	#default_action => '::first',
	 action_object  => __PACKAGE__,
        source => \(<<'END_OF_SOURCE'),
#            :default ::= action => ::array
	:default ::= action => [values]
            :start ::= Start

            Start  ::= Path action => do_arg1
            Path ::=
		 Path UNION Path	action => do_pushArgs2array
		|singlePath

	    singlePath ::=	
                 step Filter subPath action => do_stepFilterSubpath
                | step Filter action => do_stepFilter
                | step subPath action => do_stepSubpath
                | step	action => do_step

	    subPath ::= DOT singlePath action => do_arg2

	    step ::= 
		keyword action => do_keyword
		| digit action => do_digit
		| wildcard action => do_wildcard

	    Filter ::= 
		'[' Expr ']' action => do_filter
		| '[' Expr ']' Filter action => do_mergeFilters

#	    filterExpr ::= 
#		Expr action => do_arg1
#		|Expr

	   Expr ::= OrExpr action => do_arg1
           
           OrExpr ::= 
  		AndExpr
  		| OrExpr OR AndExpr 
           
	   AndExpr ::= 
		EqualityExpr
		| AndExpr AND EqualityExpr
            
	   EqualityExpr ::=
		RelationalExpr
		| EqualityExpr EQ RelationalExpr
		| EqualityExpr NE RelationalExpr
	    
	RelationalExpr ::=
		AdditiveExpr
		| RelationalExpr LT AdditiveExpr
		| RelationalExpr GT AdditiveExpr
		| RelationalExpr LE  AdditiveExpr
		| RelationalExpr GE  AdditiveExpr

	AdditiveExpr ::=
		MultiplicativeExpr
		| AdditiveExpr '+' MultiplicativeExpr
		| AdditiveExpr '-'  MultiplicativeExpr
 

	MultiplicativeExpr ::=
		UnaryExpr
		| MultiplicativeExpr '*'  UnaryExpr
		| MultiplicativeExpr '/'  UnaryExpr
		| MultiplicativeExpr '%'  UnaryExpr

	UnaryExpr ::=
		UnionExpr
		| '-' UnaryExpr

	UnionExpr ::=
		PathExpr
		| UnionExpr UNION PathExpr

	PathExpr ::= 
  		 NUMBER action => do_arg1
		| FunctionCall
		|| '(' Expr ')'
		||Path

	FunctionCall ::=
		FunctionName '(' ArgList ')' action => do_func

	FunctionName ::=
		'not'	action => do_arg1 
		| 'name' action => do_arg1
		| 'value' action => do_arg1
		| 'count' action => do_arg1

	ArgList ::=
		EMPTY
		|Arguments

	EMPTY ::=

	Arguments ::=
		Argument action => do_arg1
		| Arguments ',' Argument

	Argument ::= Expr action => do_arg1
	
	NUMBER ::=
		digit action => do_arg1
		| '+' NUMBER action => do_stringMerge
		| '-'  NUMBER action => do_stringMerge
		|digit DOT digit action => do_stringMerge
		|NUMBER EXP NUMBER action => do_stringMerge



	EXP ~ [eE]
		

	EQ ~ [=][=]
	NE ~ [!][=]
	GE ~ [<][=]
	LE ~ [>][=]
	GT ~ [>]
        LT ~ [<]	
	OR ~ [o][r]
	AND ~ [a][n][d]	
	UNION ~ [|]
	DOT ~ [.]


	    wildcard ~ [*]
            keyword ~ [a-zA-Z\N{U+A1}-\N{U+10FFFF}]+
	    digit ~ [\d]+

	:discard ~ whitespace
	whitespace ~ [\s]+

END_OF_SOURCE
    }
);
#from http://www.emacswiki.org/emacs/XPath_BNF
my $reader = Marpa::R2::Scanless::R->new(
    {
        grammar => $grammar,
        trace_terminals => 1,
    }
);


sub new { return {}; }
sub do_func{
	my $args =  [@_[3..$#_-1]];
	return {$_[1] => $args}
}
sub do_stringMerge{
	return join '', @_[1..$#_];
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
	my @array = (@$a,@$b);
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
sub do_digit{
	my $k = $_[1];
	return {digit => $k, type => 'digit'};
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
