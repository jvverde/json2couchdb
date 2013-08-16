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
my $value = shift or usage and exit;
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
$$pref = $value;

my $db = qCouchDB->new('http://localhost:5984/faturas/');
my $json = new JSON;

my $res = $db->get('_all_docs');
my $docs = $json->decode($res); 
my @ids = map{$_->{id} } @{$docs->{rows}};

foreach my $id (@ids){
	my $res = $db->get($id);
	print $res;
	last;
	my $doc = $json->decode($res); 
	#$doc->{$field} = $value unless exists $doc->{$field};
	merge($doc,$ref);
	my $text = $json->encode($doc);
	print $text;
	last;
}

sub merge{
	my $data = shift;
	my $ref = shift;
	return undef unless ref $data eq ref $ref;
	if (ref $ref eq q|HASH|){
		my @k = keys %$ref;
		my $k = $k[0];
		if (defined $data->{$k}){
			if (ref $data->{$k} and ref $data->{$k} eq ref $ref->{$k}){ 
				merge($data->{$k},$ref->{$k});
			}else{
				$data->{$k} = $ref->{$k};
			}
		}else{
			$data->{$k} = $ref->{$k};
		}
	}elsif(ref $ref eq q|ARRAY|){
		my @k = keys @$ref;
		my $k = $k[$#k];
		if (defined $data->[$k]){
			if (ref $data->[$k] and ref $data->[$k] eq ref $ref->[$k]){ 
				merge($data->[$k],$ref->[$k]);
			}else{
				$data->[$k] = $ref->[$k];
			}
		}else{
			$data->[$k] = $ref->[$k];
		}
	}
}
