# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Addon::RabbitMQ::Smoketest;

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
  "Run the smoke test errand for this deployment. This errand will not pass\n".
  "unless you have route registrar enabled.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # The smoke-tests errand only exists on broker-enabled deployments
  # (release cf-rabbitmq-smoke-tests, errand instance group in
  # manifests/broker.yml). Standalone (no-broker) deployments instead
  # colocate the cf-rabbitmq smoke-tests job on the rmq-server instance
  # group, which runs automatically on every deploy -- there is no
  # errand to invoke.
  if (!$env->has_feature('broker')) {
    $env->notify(
      "The 'smoke-tests' errand is only available when the broker feature ".
      "is enabled. This deployment runs its smoke tests automatically as ".
      "part of every deploy (colocated on the rmq-server instance group). ".
      "Use the 'acceptance-tests' addon for on-demand verification."
    );
    return $self->done();
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
