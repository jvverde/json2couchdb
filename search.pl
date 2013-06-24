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
my @path = map {
	my $filter = {
		empty => sub{
			my ($k,$v) = @_;
			return !defined $v;
		},
		eq => sub{
			my ($k,$v,$cond) = @_;
			return $v eq $cond;
		},
		ne => sub{
			my ($k,$v,$cond) = @_;
			return $v ne $cond;
		},
		le => sub{
			my ($k,$v,$cond) = @_;
			return $v le $cond;
		},
		ge => sub{
			my ($k,$v,$cond) = @_;
			return $v ge $cond;
		},
		vmatch => sub{
			my ($k,$v,$cond) = @_;
			return $v =~ /$cond/;
		},
		type => sub{
			my ($k,$v,$cond) = @_;
			return ref $v  eq /$cond/;
		},
	};
	sub mre {
		my $step = $_[0];
		my ($name,@filters) = split /\|/,$step;
		my @checks = map{ 
			my ($name,$arg) = ($_ =~ /^([^:]+)(?::(.+))?$/);
			{filter => $name, arg => $arg}
		} @filters;
		print Dumper \@checks;
		my $checkIt = sub{
			my ($key,$val) = @_;
			foreach (@checks){
				next unless exists $filter->{$_->{filter}};
				return undef unless $filter->{$_->{filter}}->($key,$val,$_->{arg});
			}
			return 1;
		};
		return $checkIt if $name eq '*';
		return sub {#last change
			return $_[0] eq $name and $checkIt->{@_};
		};
	};
	mre $_;
} split /\./, $path;
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
print Dumper $data;
my @r = findit($data,\@path, 0);
print Dumper \@r;

sub findit{
	my ($data,$path,$step) = @_;
	return () if $step > $#$path; #just in case
	my $check = $path->[$step];
	if ($step == $#$path){ #last step
		return map {\$data->{$_}} grep {$check->($_, $data->{$_})} keys %$data if ref $data eq q|HASH|;
		return map {\$data->[$_]} grep {$check->($_, $data->[$_])} (0..$#$data) if ref $data eq q|ARRAY|;
	}else{
		return map{findit($data->{$_},$path,$step+1)} grep {$check->($_, $data->{$_})} keys %$data if ref $data eq q|HASH|;
		return map{findit($data->[$_],$path,$step+1)} grep {$check->($_, $data->[$_])} (0..$#$data) if ref $data eq q|ARRAY|;
	}
	return ();
}
