#!/usr/bin/perl
use strict;
use Data::Dumper;
use  Getopt::Long;
use JSON;
use qCouchDB;
sub usage{
	print "Usage:\n\t$0 jsonPath value\n\n";
}
my $path = shift or usage and exit;
my @fields = split /\./, $path;

my $ref = undef;
my $pref = \$ref;
foreach (@fields){
	if (/^\d/){
		$pref = \($$pref->[$_] = undef);
	}else{
		$pref = \($$pref->{$_} = undef);
	}
}

my $data = {
	a => { 
		b => {
			c => '123'
		},
		bb => [
			6,
			cc => { dd => 'dd'}
		],
		bbb => [
			undef,
			1
		]
		
	}
};

my @re = map {
	sub mre{
		return qr/.+/ if $_ eq '*';
		return qr/^$_$/;
	}
	mre;
} @fields;
print Dumper \@re;
print "\n";
print Dumper $data;
my @r = findit($data,\@re, 0);
print Dumper \@r;
#$$r = [3,4];
#print Dumper $data;

sub findit{
	my ($data,$path,$step) = @_;
	return undef if $step > $#$path; #just in case
	my $key = $path->[$step];
	print "step = $step\t", "$key\n";
	if ($step == $#$path){ #last step
		return map {\$data->{$_}} grep {/$key/} keys %$data if ref $data eq q|HASH|;
		return map {\$data->[$_]} grep {/$key/} (0..$#$data) if ref $data eq q|ARRAY|;
		#return map {\$data->[$_]} if ref $data eq q|ARRAY| and $key =~ /^\d+$/ and int($key) <= $#$data;
	}else{
		if (ref $data eq q|HASH|){
			return map{findit($data->{$_},$path,$step+1)} grep {/$key/} keys %$data;
		}elsif(ref $data eq q|ARRAY|){
			return map{findit($data->[$_],$path,$step+1)} grep {/$key/} (0..$#$data);
		}	
	}
	return (undef);
}
