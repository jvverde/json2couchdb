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
	|LogicalFunction										action => do_arg1

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

LogicalFunction ::=
	'not' '(' LogicalExpr ')'			 					action => do_func
	| 'isRef' '(' PathArgs ')'			 					action => do_func
	| 'isScalar' '(' PathArgs ')'			 				action => do_func
	| 'isArray' '(' PathArgs ')'			 				action => do_func
	| 'isHash' '(' PathArgs ')'			 					action => do_func
	| 'isCode' '(' PathArgs ')'								action => do_func

StringFunction ::=
	NameFunction											action => do_arg1
	| ValueFunction											action => do_arg1

NameFunction ::= 
	'name' '(' PathArgs ')'				 					action => do_func

PathArgs ::= PathExpr*				separator => <comma>    action => do_arg1

ValueFunction ::= 
	'value' '(' PathArgs ')'				 				action => do_func

CountFunction ::= 
	'count' '(' PathArgs ')'				 				action => do_func

SumFunction ::= 
	'sum' '(' PathArgs ')'				 					action => do_func

NumericFunction ::=
	CountFunction											action => do_arg1
	|ValueFunction											action => do_arg1
	|SumFunction											action => do_arg1

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
RegularExpr ::= regularstring						action => do_re
regularstring ~ delimiter re delimiter				

delimiter ~ [/]

re ~ char*

char ~ [^/\\]
 	| '\' '/'
 	| '\\'


lstring        ~ quote in_string quote
quote          ~ ["]
 
in_string      ~ in_string_char*
 
in_string_char  ~ [^"\\]
	| '\' '"'
	| '\\'

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
	trace_terminals => 0,
});


sub new { return {}; }

sub do_condition{
	$_[1]
}
# sub do_compare{
# 	return {action => q|compare|, what => $_[1]}
# }
sub do_getPath{
	return {oper => q|get|, path => $_[1]}	
}
sub do_operationSetPathUpdate{
	return {oper => q|set|, type => $_[2], path => $_[1]}	
}
sub do_operationSetPathWithValue{
	return {oper => q|assignvalue|, type => $_[2], path => $_[1], value => $_[3]}	
}
sub do_operationSetPathFromPath{
	return {oper => q|assignfrompath|, type => $_[2], path => $_[1], fromPath => $_[3]}	
}
sub do_re{
	my $re = $_[1];
	$re =~ s/^\/|\/$//g;
	return qr/$re/;
}
sub do_string {
    my $s = $_[1]; 
    $s =~ s/^"|"$//g;
    return $s;
}
sub do_func{
	my $args =	@_[3..$#_-1];
	return {oper => [$_[1], $args ? $args : []]}
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
# print "********root**********";
# print Dumper $root;
# print "********/root**********";
my @context = ();
sub arithmeticOper(&$$;@){
		my ($oper,$x,$y,@e) = @_;
		$x = operation($x) if ref $x;
		$y = operation($y) if ref $y;
		my $res = $oper->($x,$y);
		foreach my $e (@e){
			$e = operation($e) if ref $e;
			$res = $oper->($res,$e);
		}
		return $res
}
sub logicalOper(&$$){
		my ($oper,$x,$y) = @_;
		$x = operation($x) if ref $x and ref $x ne q|Regexp|;
		$y = operation($y) if ref $y and ref $y ne q|Regexp|;
		return $oper->($x,$y)
}
my $filtersProc;
$filtersProc = {
	'eq' => sub($$){
		return logicalOper(sub {$_[0] eq $_[1]}, $_[0], $_[1]);
	},
	'ne' => sub($$){
		return logicalOper(sub {$_[0] ne $_[1]}, $_[0], $_[1]);
	},
	'==' => sub($$){
		return logicalOper(sub {$_[0] == $_[1]}, $_[0], $_[1]);
	},
	'!=' => sub($$){
		return logicalOper(sub {$_[0] != $_[1]}, $_[0], $_[1]);
	},
	'>' => sub($$){
		return logicalOper(sub {$_[0] > $_[1]}, $_[0], $_[1]);
	},
	'>=' => sub($$){
		return logicalOper(sub {$_[0] >= $_[1]}, $_[0], $_[1]);
	},
	'<' => sub($$){
		return logicalOper(sub {$_[0] < $_[1]}, $_[0], $_[1]);
	},
	'<=' => sub($$){
		return logicalOper(sub {$_[0] <= $_[1]}, $_[0], $_[1]);
	},
	'>=' => sub($$){
		return logicalOper(sub {$_[0] >= $_[1]}, $_[0], $_[1]);
	},
	'lt' => sub($$){
		return logicalOper(sub {$_[0] lt $_[1]}, $_[0], $_[1]);
	},
	'le' => sub($$){
		return logicalOper(sub {$_[0] le $_[1]}, $_[0], $_[1]);
	},
	'gt' => sub($$){
		return logicalOper(sub {$_[0] gt $_[1]}, $_[0], $_[1]);
	},
	'ge' => sub($$){
		return logicalOper(sub {$_[0] ge $_[1]}, $_[0], $_[1]);
	},
	'and' => sub($$){
		return logicalOper(sub {$_[0] and $_[1]}, $_[0], $_[1]);
	},
	'or' => sub($$){
		return logicalOper(sub {$_[0] or $_[1]}, $_[0], $_[1]);
	},
	'~' => sub($$){
		return logicalOper(sub {$_[0] =~ $_[1]}, $_[0], $_[1]);
	},
	'!~' => sub($$){
		return logicalOper(sub {$_[0] !~ $_[1]}, $_[0], $_[1]);
	},
	'+' => sub($$;@){
		return arithmeticOper(sub {$_[0] + $_[1]}, $_[0], $_[1], @_[2..$#_]);
	},
	'*' => sub($$;@){
		return arithmeticOper(sub {$_[0] * $_[1]}, $_[0], $_[1], @_[2..$#_]);
	},
	'/' => sub($$;@){
		return arithmeticOper(sub {$_[0] / $_[1]}, $_[0], $_[1], @_[2..$#_]);
	},
	'-' => sub($$;@){
		return arithmeticOper(sub {$_[0] - $_[1]}, $_[0], $_[1], @_[2..$#_]);
	},
	'%' => sub($$;@){
		return arithmeticOper(sub {$_[0] % $_[1]}, $_[0], $_[1], @_[2..$#_]);
	},
	names => sub{
		return map {$_->{step}} getSubObjectsOrCurrent(@_);
	},
	name => sub{
		my @r = $filtersProc->{names}->(@_);
		return $r[0] if defined $r[0];
		return q||; 
	},
	value => sub(){
		my @r = $filtersProc->{values}->(@_);
		return $r[0] if defined $r[0];
		return q||; 
	},
	values => sub{
		return map {${$_->{data}}} getSubObjectsOrCurrent(@_);
	},
	isHash => sub{
		my @r = grep {ref ${$_->{data}} eq q|HASH|} getSubObjectsOrCurrent(@_);
		return @r > 0;
	},
	isArray => sub{
		my @r = grep {ref ${$_->{data}} eq q|ARRAY|} getSubObjectsOrCurrent(@_);
		return @r > 0;	
	},
	isCode => sub{
		my @r = grep {ref ${$_->{data}} eq q|CODE|} getSubObjectsOrCurrent(@_);
		return @r > 0;				
	},
	isRef => sub{
		my @r = grep {ref ${$_->{data}}} getSubObjectsOrCurrent(@_);
		return @r > 0;	
	},
	isScalar => sub{
		my @r = grep {!ref ${$_->{data}}} getSubObjectsOrCurrent(@_);
		return @r > 0;		
	},
	count =>sub{
		my @r = getSubObjectsOrCurrent(@_);
		return scalar @r;
	},
	exists => sub{
		my @r = getSubObjectsOrCurrent(@_);
		return scalar @r > 0;		
	},
	not => sub{
		return !operation($_[0]);
	}
};
sub getSubObjectsOrCurrent{
	my $paths = $_[0];
	my @r = ();
	return ($context[$#context]) if scalar @$paths == 0;
	foreach my $path (@$paths){
		my @objs = getNodeSet(${$context[$#context]->{data}},$path);
		foreach my $obj (@objs){
			push @r, $obj;
		}	
	}
	return @r;
}
sub operation($){
	my $operData = $_[0];
	return undef unless defined $operData and ref $operData eq "HASH" and exists $operData->{oper};
	my @params = @{$operData->{oper}};
	my $oper = $params[0];
	return undef unless exists $filtersProc->{$oper};
	my @args = @params[1..$#params];
	return $filtersProc->{$oper}->(@args);  
}
sub check{
	my ($filter) = @_;
	return 1 unless defined $filter; #no filter always returns true
	foreach (@$filter){
		return 0 unless operation($_)
	}
	return 1;	#true
}

my $indexesProc;
$indexesProc = {
	index => sub{
		my ($data, $index, $subpath,$filter) = @_;
		$index += $#$data + 1 if $index < 0;
		return () unless $data->[$index];
		my @r = ();	
		#$subpath->{currentObj} = $data->[$index] if defined $subpath;
		push @context, {step => $index, data  => \$data->[$index], type => q|index|};
		sub{
			return if defined $filter and !check($filter); 
			push @r, 
				defined $subpath ? 
					getNodeSet($data->[$index],$subpath)
					:{data => \$data->[$index], step => $index, context => [@context]}
		}->();
		pop @context;
		return @r;
	},
	range => sub{
		my ($data, $range, $subpath, $filter) = @_;
		my ($start, $stop) = @{$range};
		$start += $#$data + 1 if $start < 0;
		$stop += $#$data + 1 if $stop < 0;
		$stop = $#$data if $stop > $#$data;
		my @indexes = $start <= $stop ?
			($start..$stop)
			: reverse ($stop..$start);
		my @r = ();
		push @r, $indexesProc->{index}->($data,$_,$subpath,$filter)
			foreach (@indexes);
		return @r;
	},
	from => sub{
		my ($data, $from, $subpath,$filter) = @_;
		$from += $#$data + 1 if $from < 0;
		my @indexes = ($from..$#$data);
		my @r = ();
		push @r, $indexesProc->{index}->($data,$_,$subpath,$filter)
			foreach (@indexes);
		return @r;			
	},
	to => sub{
		my ($data, $to, $subpath,$filter) = @_;	
		$to += $#$data + 1 if $to < 0;
		my @indexes = (0..$to);
		my @r = ();
		push @r, $indexesProc->{index}->($data,$_,$subpath,$filter)
			foreach (@indexes);
		return @r;	
	},

};

my $keysProc;
$keysProc = {
	step => sub{
		my ($data, $step, $subpath,$filter) = @_;
		return () unless exists $data->{$step};

		my @r = ();
		#$subpath->{currentObj} = $data->{$step} if defined $subpath;
		push @context, {step => $step, data  => \$data->{$step}, type => q|key|};
		sub{	
			return if defined $filter and !check($filter); 
			push @r, 
				defined $subpath ? 
					getNodeSet($data->{$step}, $subpath)
					: {data => \$data->{$step}, step => $step, context => [@context]};
		}->();
		pop @context;
		return @r;
	},
	wildcard => sub{
		my ($data, undef, $subpath,$filter) = @_;
		my @r = ();
		push @r, $keysProc->{step}->($data, $_, $subpath,$filter)
			foreach (keys %$data);
		return @r;
	}
};

sub getNodeSet{
	my ($data,$path) = @_;
	return () unless ref $path eq q|HASH|;

	my @r = ();
	if (ref $data eq q|HASH|){
		my @keys = grep{exists $path->{$_}} keys %$keysProc;
		push @r, $keysProc->{$_}->($data, $path->{$_}, $path->{subpath}, $path->{filter})
			foreach (@keys);
	}elsif(ref $data eq q|ARRAY|){
		my $indexes = $path->{indexes};
		return () unless defined $indexes;
		foreach my $entry (@$indexes){
			push @r, $indexesProc->{$_}->($data,$entry->{$_},$path->{subpath},$path->{filter})
				foreach (grep {exists $indexesProc->{$_}} keys %$entry); 	#just in case use grep to filter out not supported indexes types
		}
	}
	return @r;
}
sub getObjects{
		return map {getNodeSet($_[0],$_)}  (@_[1..$#_]);
}

my $method = {
	get => sub{
		my ($expression,$data) = @_;
		return getObjects($data, @{$expression->{path}});	
	},
	assignvalue => sub{
		my ($expression,$data) = @_;
		my @r = getObjects($data, @{$expression->{path}});
		do {${$_->{data}} = $expression->{value}} foreach (@r);
		return @r;	
	},
	assignfrompath => sub {
		my ($expression,$data) = @_;
		my @r = getObjects($data, @{$expression->{path}});
		my @values = map {${$_->{data}}} getObjects($data, @{$expression->{fromPath}});
		${$_->{data}} = shift @values foreach my (@r);
		return @r;			
	}
};
my $test = 12345;
my $data = {
	a =>{
		b =>{
			c => 3
		},
		bb =>{
			cc => 4,
		},
		bbb => sub{
			print "this is code";
		}
	},
	aa =>{
		bb =>{
			cc => 5
		},
		c => "cccccccccccccccccccc"
	},
	xx => [
		12,
		$test,
		{y => {zz => 'ccccc', ww=>'dddd'}},
		'ww',
		987,
		[1,
			4,
			7,
			{q=>q|qqqqq|}
		]	
	]

};
print "----------------------Path--------------------";
print Dumper $root;

#my @r = getObjects($data, @{${$root}->{path}});
my @r = $method->{${$root}->{oper}}->(${$root}, $data);

print "-----------------------Result--------------------";
print Dumper [map {$_->{data}} @r];

print "-----------------------Data--------------------";
print Dumper $data;
#print Dumper $data;
