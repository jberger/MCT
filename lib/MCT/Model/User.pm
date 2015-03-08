package MCT::Model::User;

use MCT::Model -row;

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

sub _load_sst {
  my $self = shift;
  my $key = $self->id ? 'id' : 'username';

  return(
    sprintf('SELECT %s FROM users WHERE %s=?', join(', ', $self->columns), $key),
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

