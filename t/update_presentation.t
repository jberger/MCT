use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

plan skip_all => 'set TEST_ONLINE'
  unless $ENV{MCT_DATABASE_DSN} = $ENV{TEST_ONLINE};

$ENV{MCT_MOCK} = 1;

my $t = Test::Mojo->new('MCT');

my $app = $t->app;

$app->migrations->migrate(0);
$app->migrations->migrate;

$t->get_ok('/user/connect', form => {code => 42})->status_is(302);

$t->app->model->conference(
  name => 'Mojoconf 2015',
  identifier => '2015',
  tagline => 'All the Mojo you can conf',
)->save;

$t->get_ok('/2015/presentations')
  ->status_is(200)
  ->text_is('title' => 'Mojoconf 2015 - Submit a presentation')
  ->element_exists('input[name="title"]')
  ->element_exists('textarea[name="abstract"]');

my $pres = {
  title => 'My Title',
  abstract => 'My content here',
};
my $location = '/2015/presentations/my_title';
$t->post_ok('/2015/presentations', form => $pres)
  ->status_is(302)
  ->header_is('Location' => $location);

$t->get_ok($location)
  ->status_is(200)
  ->text_is('title' => 'Mojoconf 2015 - My Title')
  ->text_is('#title' => 'My Title')
  ->text_is('#author' => 'Presented by: John Doe')
  ->text_is('#abstract' => 'My content here');

$t->get_ok("$location/edit")
  ->status_is(200)
  ->text_is('title' => 'Mojoconf 2015 - Edit: My Title')
  ->element_exists('input[name="title"][value="My Title"]')
  ->text_is('textarea[name="abstract"]' => 'My content here');

# add the id and make a change
$pres->{id} = $t->tx->res->dom->at('input[name="id"]')->{value};
$pres->{abstract} = 'New content here';

$t->post_ok('/2015/presentations', form => $pres)
  ->status_is(302)
  ->header_is('Location' => $location);

$t->get_ok($location)
  ->status_is(200)
  ->text_is('title' => 'Mojoconf 2015 - My Title')
  ->text_is('#title' => 'My Title')
  ->text_is('#author' => 'Presented by: John Doe')
  ->text_is('#abstract' => 'New content here');

# change the title (and thus url_name)
$pres->{title} = 'Some New Title';
my $new_location = '/2015/presentations/some_new_title';

$t->post_ok('/2015/presentations', form => $pres)
  ->status_is(302)
  ->header_is('Location' => $new_location);

$t->get_ok($location)
  ->status_is(404);

$t->get_ok($new_location)
  ->status_is(200)
  ->text_is('title' => 'Mojoconf 2015 - Some New Title')
  ->text_is('#title' => 'Some New Title')
  ->text_is('#author' => 'Presented by: John Doe')
  ->text_is('#abstract' => 'New content here');

$t->reset_session;

# attempt to view edit page without permission
$t->get_ok("$new_location/edit")
  ->status_is(401)
  ->content_is('Not authorized');

# attempt to update the presentation without permission
my %bad = (%$pres, abstract => 'This is bad');
$t->post_ok('/2015/presentations', form => \%bad)
  ->status_is(401)
  ->content_is('Not authorized');

$t->get_ok($new_location)
  ->status_is(200)
  ->text_is('#abstract' => $pres->{abstract}, 'abstract not changed');

done_testing;

