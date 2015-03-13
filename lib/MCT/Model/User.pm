package MCT::Model::User;

use MCT::Model -row;
use MCT::Model::Presentation;

col id => undef;

# optional
col address => '';
col avatar_url => '';
col city => '';
col country => '';
col t_shirt_size => '';
col web_page => '';
col zip => '';

# required
col email => '';
col name => '';
col username => sub { shift->email };

has conference => '';

sub avatar {
  my ($self, %args) = @_;
  my $url = Mojo::URL->new($self->avatar_url);

  $url->query({size => $args{size}}) if $args{size};
  $url;
}

sub is_admin { shift->{is_admin} ? 1 : 0 }
sub is_going { shift->{is_going} ? 1 : 0 }
sub payed { shift->{payed} || 0 }

sub validate {
  my ($self, $validation) = @_;

  $validation->optional('address');
  $validation->optional('avatar_url');
  $validation->optional('city');
  $validation->optional('country')->country;
  $validation->optional('t_shirt_size')->in($self->valid_t_shirt_sizes);
  $validation->optional('web_page')->like(qr!^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?!); # from Mojo::URL
  $validation->optional('zip')->like(qr!^[a-z0-9-]+$!i);

  $validation->required('email')->like(qr{\@}); # poor mans email regex
  $validation->required('name')->like(qr{\w..});
  $validation->required('username')->like(qr{^...});
  $validation;
}

sub valid_t_shirt_sizes { qw( XS S M XL XXL ) }

sub presentations {
  my ($self, $cb) = @_;
  #TODO add ability to only select by conference
  #TODO select status once it exists

  my $sql = <<'  SQL';
    SELECT
      p.id,
      p.duration,
      p.status,
      p.url_name as url_name,
      p.title as title,
      p.abstract as abstract,
      c.identifier as conference,
      c.name as conference_name,
      u.username as author,
      u.name as author_name
    FROM presentations p
    JOIN conferences c ON c.id=p.conference_id
    JOIN users u ON u.id=p.user_id
    WHERE p.user_id=?
    ORDER BY c.created DESC, p.title
  SQL

  Mojo::IOLoop->delay(
    sub { $self->_query($sql, $self->id, shift->begin) },
    sub {
      my ($delay, $err, $results) = @_;
      die $err if $err;
      $self->$cb(undef, [map { MCT::Model::Presentation->new(%$_, db => $self->db) } $results->hashes->each]);
    },
  )->catch(sub{ $self->$cb($_[1], undef) })->wait;

  return $self;
}

sub _load_sst {
  $_[0]->conference ? $_[0]->_load_sst_with_conference : $_[0]->_load_sst_without_conference;
}

sub _load_sst_without_conference {
  my $self = shift;
  my $key = $self->id ? 'id' : 'username';

  return(
    sprintf('SELECT %s FROM users WHERE %s=?', join(', ', $self->columns), $key),
    $self->$key,
  );
}

sub _load_sst_with_conference {
  my $self = shift;
  my $key = $self->id ? 'id' : 'username';

  my $sql = <<'  SQL';
    SELECT
      %s,
      uc.admin as is_admin,
      uc.going as is_going,
      uc.payed as payed
    FROM users u
    JOIN user_conferences uc ON u.id=uc.user_id
    JOIN conferences c ON c.id=uc.conference_id
    WHERE c.identifier=? AND u.%s=?
  SQL

  return(
    sprintf($sql, join(', ', map { "u.$_ as $_" } $self->columns), $key),
    $self->conference,
    $self->$key,
  );
}

sub _insert_sst {
  my $self = shift;
  my @cols = grep { $_ ne 'id' } $self->columns;

  return(
    sprintf(
      'INSERT INTO users (registered, %s) VALUES (CURRENT_TIMESTAMP, %s) RETURNING id',
      join(', ', @cols),
      join(', ', map { '?' } @cols),
    ),
    map { $self->$_ } @cols
  );
}

sub _update_sst {
  my $self = shift;
  my @cols = grep { $_ ne 'id' } $self->columns;

  return(
    sprintf(
      'UPDATE users SET %s WHERE id=?',
      join(', ', map { "$_=?" } @cols),
    ),
    (map { $self->$_ } @cols),
    $self->id,
  );
}

sub TO_JSON {
  my $self = shift;
  return { map { ($_, $self->$_) } qw( name username email id ) };
}

1;

