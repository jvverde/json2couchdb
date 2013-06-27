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

Start	::= OperExp									action => do_arg1

OperExp ::=
	PathExpr 										action => do_getPath
	| PathExpr Operator 							action => do_operationSetPathUpdate
	| PathExpr Operator Value						action => do_operationSetPathWithValue
	| PathExpr Operator PathExpr					action => do_operationSetPathFromPath

Operator ::= '='									action => do_arg1

Value ::=
	NumericExpr										action => do_arg1
	|StringExpr 									action => do_arg1


PathExpr ::=
	singlePath										action => do_singlePath
	| PathExpr '|' singlePath						action => do_pushArgs2array

singlePath ::=	
	stepPath 										action => do_arg1
	|indexPath 										action => do_arg1

stepPath ::=
	step Filter subPathExpr 						action => do_stepFilterSubpath
	| step Filter 									action => do_stepFilter
	| step subPathExpr 								action => do_stepSubpath
	| step											action => do_arg1

step ::= 
	keyword 										action => do_keyword
	| wildcard 										action => do_wildcard

subPathExpr ::= 
	'.' stepPath 									action => do_arg2
	|indexPath 										action => do_arg1

indexPath ::=
	IndexArray Filter subPathExpr 					action => do_indexFilterSubpath	
	| IndexArray Filter 							action => do_indexFilter	
	| IndexArray subPathExpr 						action => do_indexSubpath		
	| IndexArray									action => do_arg1	


IndexArray ::=  '[' IndexExprs ']'					action => do_index


IndexExprs ::= IndexExpr* 			separator => <comma>

IndexExpr ::=
	IntegerExpr										action => do_index_single
	| rangeExpr										action => do_arg1

rangeExpr ::= 
	IntegerExpr '..' IntegerExpr 					action => do_index_range
	|IntegerExpr '...' 								action => do_startRange
	| '...' IntegerExpr								action => do_endRange


Filter ::= 	
	'{' LogicalExpr '}' 							action => do_filter
	| '{' LogicalExpr '}' Filter 					action => do_mergeFilters

IntegerExpr ::=
  ArithmeticIntegerExpr										action => do_arg1

 ArithmeticIntegerExpr ::=
 	INT 													action => do_arg1
	| IntegerFunction										action => do_arg1
	| '(' IntegerExpr ')' 									action => do_group
	|| '-' ArithmeticIntegerExpr 							action => do_unaryOperator
	 | '+' ArithmeticIntegerExpr 							action => do_unaryOperator
	|| ArithmeticIntegerExpr '*' ArithmeticIntegerExpr		action => do_binaryOperator
	 | ArithmeticIntegerExpr '/' ArithmeticIntegerExpr		action => do_binaryOperator
	 | ArithmeticIntegerExpr '%' ArithmeticIntegerExpr		action => do_binaryOperator
	|| ArithmeticIntegerExpr '+' ArithmeticIntegerExpr		action => do_binaryOperator
	 | ArithmeticIntegerExpr '-' ArithmeticIntegerExpr		action => do_binaryOperator


NumericExpr ::=
  ArithmeticExpr 											action => do_arg1

ArithmeticExpr ::=
	NUMBER 													action => do_arg1
	| NumericFunction										action => do_arg1
	| '(' NumericExpr ')' 									action => do_group
	|| '-' ArithmeticExpr 									action => do_unaryOperator
	 | '+' ArithmeticExpr 									action => do_unaryOperator
	|| ArithmeticExpr '*' ArithmeticExpr					action => do_binaryOperator
	 | ArithmeticExpr '/' ArithmeticExpr					action => do_binaryOperator
	 | ArithmeticExpr '%' ArithmeticExpr					action => do_binaryOperator
	|| ArithmeticExpr '+' ArithmeticExpr					action => do_binaryOperator
	 | ArithmeticExpr '-' ArithmeticExpr					action => do_binaryOperator

LogicalExpr ::=
	compareExpr												action => do_arg1
	|LogicalFunction

compareExpr ::=	
	PathExpr 												action => do_exists
	|| NumericExpr '<' NumericExpr							action => do_binaryOperator
	 | NumericExpr '<=' NumericExpr							action => do_binaryOperator
	 | NumericExpr '>' NumericExpr							action => do_binaryOperator
	 | NumericExpr '>=' NumericExpr							action => do_binaryOperator
	 | StringExpr 'lt' StringExpr							action => do_binaryOperator
	 | StringExpr 'le' StringExpr							action => do_binaryOperator
	 | StringExpr 'gt' StringExpr							action => do_binaryOperator
	 | StringExpr 'ge' StringExpr							action => do_binaryOperator
	 | StringExpr '~' RegularExpr							action => do_binaryOperator
	 | StringExpr '!~' RegularExpr							action => do_binaryOperator
	 | NumericExpr '==' NumericExpr							action => do_binaryOperator
	 | NumericExpr '!=' NumericExpr							action => do_binaryOperator
	 | StringExpr 'eq' StringExpr							action => do_binaryOperator
	 | StringExpr 'ne' StringExpr							action => do_binaryOperator
	|| compareExpr 'and' LogicalExpr						action => do_binaryOperator
	|| compareExpr 'or' LogicalExpr							action => do_binaryOperator

#operator match, not match, in, intersect, union,

StringExpr ::=
	STRING 													action => do_arg1
 	| StringFunction 										action => do_arg1
 	|| StringExpr '||' StringExpr  							action => do_binaryOperator


# UserDefinedFunction ::=
# 	FunctionName '(' ArgList ')' 							action => do_func

# ArgList ::= Argument* separator => <comma>

# Argument ::= Expr 											action => do_arg1

# Expr ::=
# 	NumericExpr												action => do_arg1		
# 	|LogicalExpr											action => do_arg1

LogicalFunction ::=
	'not' '(' LogicalExpr ')'			 					action => do_func

StringFunction ::=
	'name' '(' PathExpr ')'				 					action => do_func
	| ValueFunction

ValueFunction ::= 
	'value' '(' PathExpr ')'				 				action => do_func

CountFunction ::= 
	'count' '(' PathExpr ')'				 				action => do_func

NumericFunction ::=
	CountFunction											action => do_arg1
	|ValueFunction											action => do_arg1

IntegerFunction ::=
	CountFunction											action => do_arg1


 NUMBER ::= UNUMBER 										action => do_arg1
 	| '-' UNUMBER 											action => do_join
 	| '+' UNUMBER 											action => do_join

UNUMBER  
	~ unumber       

unumber	
	~ uint
	| uint frac
	| uint exp
	| uint frac exp
 
uint            
	~ digits
#	| '-' digits
#	| '+' digits

 
digits 
	~ [\d]+
 
frac
	~ '.' digits
 
exp
	~ e digits
 
e
	~ 'e'
	| 'e+'
	| 'e-'
	| 'E'
	| 'E+'
	| 'E-'

INT ::= 
	UINT 											action => do_arg1
	| '+' UINT  									action => do_join
	| '-' UINT  									action => do_join

UINT
	~digits

STRING       ::= lstring               				action => do_string
RegularExpr ~ delimiter re delimiter				

delimiter ~ [/]

 re ~ char*

 char ~ [^/\\]
 	| '\' [^\\]
 	| '\\'


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

#FunctionName  ~ []

comma ~ ','

wildcard ~ [*]
keyword ~ [a-zA-Z\N{U+A1}-\N{U+10FFFF}]+

:discard ~ WS
WS ~ [\s]+

END_OF_SOURCE
});

#from http://www.emacswiki.org/emacs/XPath_BNF
my $reader = Marpa::R2::Scanless::R->new({
	grammar => $grammar,
	trace_terminals => 1,
});


sub new { return {}; }

sub do_condition{
	$_[1]
}
# sub do_compare{
# 	return {action => q|compare|, what => $_[1]}
# }
sub do_getPath{
	return {oper => q|GET|, path => $_[1]}	
}
sub do_operationSetPathUpdate{
	return {oper => q|SET|, type => $_[2], path => $_[1]}	
}
sub do_operationSetPathWithValue{
	return {oper => q|SET|, type => $_[2], path => $_[1], value => $_[3]}	
}
sub do_operationSetPathFromPath{
	return {oper => q|SET|, type => $_[2], path => $_[1], fromPath => $_[3]}	
}
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
	my $args =	@_[3..$#_-1];
	return {func => [$_[1], $args]}
}
sub do_join{
	return join '', @_[1..$#_];
}
sub do_group{
	return $_[2]
}
sub do_unaryOperator{
	return {oper => [@_[1,2]]}
}
sub do_binaryOperator{
	my $oper = 	[$_[2]];
	my $args = 	[@_[1,3]];
	foreach my $i (0..$#$args){
		if (ref $args->[$i] eq q|HASH| 
			and defined $args->[$i]->{q|oper|} 
			and $args->[$i]->{q|oper|}->[0] eq $oper->[0]){
			my $list = $args->[$i]->{q|oper|};
			push @$oper, @{$list}[1..$#$list];
		}else{
			push @$oper, $args->[$i]; 
		} 
	}
	return {oper => $oper};
}
sub do_exists{
	return {oper => [q|exists|, $_[1]]}
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
sub do_indexFilterSubpath(){
	my ($index, $filter, $subpath) = @_[1..3];
	warn q|arg is not a hash ref| unless ref $index eq 'HASH'; 
	@{$index}{qw|filter subpath|} = ($filter,$subpath);
	return $index;
}
sub do_indexFilter(){
	my ($index, $filter) = @_[1,2];
	warn q|arg is not a hash ref| unless ref $index eq 'HASH'; 
	$index->{filter} = $filter;
	return $index;
}
sub do_indexSubpath{
	my ($index,$subpath) = @_[1,2];
	warn q|arg is not a hash ref| unless ref $index eq 'HASH'; 
	$index->{subpath} = $subpath;
	return $index;
}


sub do_arg1{ return $_[1]};
sub do_arg2{ return $_[2]};
sub do_pushArgs2array{
	my ($a,$b) = @_[1,3];
	my @array = (@$a,$b);
	return \@array;
}
sub do_singlePath{
	return [$_[1]];
}
sub do_filter{ return [$_[2]]};
sub do_mergeFilters{
	my ($filter, $filters) = @_[2,4];
	my @filters = ($filter, @$filters);
	return \@filters; 
}
sub do_index{
	return {indexes => $_[2]}
}
sub do_index_single{
	return {index => $_[1]}
}
sub do_index_range{
	return {range => [@_[1,3]]}
}
sub do_startRange{
	{from => $_[1]}
}
sub do_endRange{
	{to => $_[2]}
}
sub do_keyword{
	my $k = $_[1];
	return {step => $k};
}

sub do_wildcard{
	my $k = $_[1];
	return {wildcard => $k};
}

my $input = shift || <>;
chomp $input;
#print "input = $input\n"; 
$reader->read(\$input);
my $root = $reader->value;
print "********root**********";
print Dumper $root;
print "********/root**********";
sub check{
	my ($data, $filter) = @_;
	return 1 unless defined $filter;
	return 0;	
}
sub getNodeSet{
	my ($data, $path) = @_;

	if (ref $data eq q|HASH|){
		if (defined $path->{step}){	
			return () unless exists $data->{$path->{step}} 
				and check($data->{$path->{step}}, $path->{filter});
			if ($path->{subpath}){
				return getNodeSet($data->{$path->{step}}, $path->{subpath})
			}else{	
				return (\$data->{$path->{step}})
			}
		}elsif(defined $path->{wildcard}){
			my @r = ();
			if ($path->{subpath}){
				foreach my $k (keys %$data){
					push @r, getNodeSet($data->{$k}, $path->{subpath})
						if check($data->{$path->{$k}, $path->{filter})
				}			
			}else{
				foreach my $k (keys %$data){
					push @r, \$data->{$k}
						if check($data->{$path->{$k}, $path->{filter})
				}
			}
			return @r;
		}else{
			return ();
		}	
	}elsif(ref $data eq q|ARRAY|){
		my $indexes = $path->{indexes};
		if (defined $indexes){
			my @r = ();
			if ($path->{subpath}){
				foreach my $entry (@$indexes){
					if (defined $data->[$entry->{index}]){
						push @r, getNodeSet($data->[$entry->{index}], $path->{subpath})
					}
				}
			}else{
				foreach my $entry (@$indexes){
					if (defined $data->[$entry->{index}]){
						push @r, \$data->[$entry->{index}]
					}
				}
			}
			return @r;
		}else{
			return ()
		}			
	}
	warn "Shouldn't occur!!";
	return ();

}

my $data = {
	a =>{
		b =>{
			c => 3
		},
		bb =>{
			cc => 4
		}
	},
	aa =>{
		bb =>{
			cc => 5
		}
	},
	xx => [
		12,
		yy => {zz => 'ccccc', ww=>'dddd'}	
	]

};

my @r = getNodeSet($data, ${$root}->{path}->[0]);

print Dumper \@r;

${@r[0]} = 'yyyyyyyyyyyyyy' if defined @r[0] and ref @r[0];
print Dumper $data;
