# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Addon::RabbitMQ::Smoketest;

use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Run the smoke test errand for this deployment. This errand will not pass\n".
  "unless you have route registrar enabled.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Check if broker feature is enabled (required for smoke tests)
  if (!$env->has_feature('broker')) {
    $env->notify(error => "Cannot run smoke tests: broker feature is not enabled for this environment.");
    return 0;
  }

  # Route registrar warning
  if (!$env->has_feature('route-registrar')) {
    $env->notify(warning => "Route registrar feature is not enabled. Smoke tests may fail.");
  }

  $env->notify("Running RabbitMQ smoke tests...");

  my ($out, $rc, $err) = run({ interactive => 1 }, 'bosh run-errand smoke-tests');

  if ($rc != 0) {
    $env->notify(error => "Smoke tests failed: $err");
    return 0;
  }

  $env->notify(success => "RabbitMQ smoke tests completed successfully.");
  return $self->done();
}

1;
