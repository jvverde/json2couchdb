package qCouchDB;

use strict;
use warnings;

use LWP::UserAgent;

sub new {
  my ($class, $resource) = @_;

  my $ua = LWP::UserAgent->new;
  $ua->timeout(10);
  $ua->env_proxy;

  return bless {
                ua       => $ua,
                dbUri => $resource,
               }, $class;
}

sub ua { shift->{ua} }
sub dbUri { shift->{dbUri} }

sub request {
  my ($self, $method, $resource, $content) = @_;

  my $full_uri = $self->dbUri . $resource;
  my $req;

  if (defined $content) {
    #Content-Type: application/json

    $req = HTTP::Request->new( $method, $full_uri, undef, $content );
    $req->header('Content-Type' => 'application/json');
  } else {
    $req = HTTP::Request->new( $method, $full_uri );
  }

  my $response = $self->ua->request($req);

  if ($response->is_success) {
    return $response->content;
  } else {
    die($response->status_line . ":" . $response->content);
  }
}

sub delete {
  my ($self, $resource) = @_;

  $self->request(DELETE => $resource);
}

sub get {
  my ($self, $resource) = @_;

  $self->request(GET => $resource);
}

sub put {
  my ($self, $resource, $json) = @_;

  $self->request(PUT => $resource, $json);
}

sub post {
  my ($self, $resource, $json) = @_;

  $self->request(POST => $resource, $json);
}

1;

