# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Features::RabbitMQ;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Add all the requested features
  foreach my $feature (@{$self->{features}}) {
    $self->add_feature($feature);
  }

  # Derived features based on absence of other features
  if (!$self->has_feature("no-rmq-tls") && !$self->has_feature("provided-rmq-cert")) {
    $self->add_feature("+rmq-tls");
  }

  if (!$self->has_feature("no-mgmt-tls") && !$self->has_feature("provided-mgmt-cert")) {
    $self->add_feature("+mgmt-tls");
  }

  if ($self->has_feature("broker") &&
    !$self->has_feature("no-broker-tls") &&
    !$self->has_feature("provided-broker-cert")) {
    $self->add_feature("+broker-tls");
  }

  return $self->done();
}

1;
