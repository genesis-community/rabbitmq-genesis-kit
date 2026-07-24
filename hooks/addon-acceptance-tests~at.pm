# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Addon::RabbitMQ::AcceptanceTests;

use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::Addon);
sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Run the acceptance test errand for this deployment. This errand\n".
  "exercises AMQP, management, cluster, HAProxy, and plugin checks\n".
  "against the deployed RabbitMQ cluster.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  $env->notify("Running RabbitMQ acceptance tests...");

  my ($out, $rc, $err) = run({ interactive => 1 }, 'bosh run-errand acceptance-tests');

  if ($rc != 0) {
    $env->notify(error => "Acceptance tests failed: $err");
    return 0;
  }

  $env->notify(success => "RabbitMQ acceptance tests completed successfully.");
  return $self->done();
}

1;
