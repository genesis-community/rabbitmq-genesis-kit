# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Addon::RabbitMQ::RegisterBroker;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use Genesis qw/bail info run/;

use parent qw(Genesis::Hook::Addon);
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Register this broker with the Cloud Foundry in this environment.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Check if broker feature is enabled
  if (!$env->has_feature('broker')) {
    $env->notify(error => "Cannot register broker: broker feature is not enabled for this environment.");
    return 0;
  }

  $env->notify("Registering RabbitMQ broker with Cloud Foundry...");

  my ($out, $rc, $err) = run({ interactive => 1 }, 'bosh run-errand broker-registrar');

  if ($rc != 0) {
    $env->notify(error => "Failed to register broker with Cloud Foundry: $err");
    return 0;
  }

  $env->notify(success => "RabbitMQ broker successfully registered with Cloud Foundry.");
  return $self->done();
}

1;
