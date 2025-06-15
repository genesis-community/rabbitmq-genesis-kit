# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::PreDeploy::RabbitMQ;

use v5.20;
use warnings; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'./.genesis/lib'}

use parent qw(Genesis::Hook::PreDeploy);
sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  $env->notify("Running pre-deployment checks for RabbitMQ...");

  # Check if required credentials are present in vault
  my $vault_prefix = $ENV{GENESIS_VAULT_PREFIX};

  # Check for admin credentials
  my $admin_password = $self->vault->get("$vault_prefix/admin:password");
  if (!$admin_password) {
    $env->notify(warning => "Admin password not found in vault. Will be generated during deployment.");
  }

  # For broker feature, check for broker credentials
  if ($env->has_feature('broker')) {
    my $broker_password = $self->vault->get("$vault_prefix/broker:password");
    if (!$broker_password) {
      $env->notify(warning => "Broker password not found in vault. Will be generated during deployment.");
    }

    # Check if broker domain is set
    my $broker_domain = $env->lookup('params.broker_domain');
    if (!$broker_domain) {
      $env->notify(warning => "Broker domain (params.broker_domain) not specified. Service registration may fail.");
    }
  }

  # Check if RabbitMQ domain is set
  my $rmq_domain = $env->lookup('params.rmq_domain');
  if (!$rmq_domain) {
    $env->notify(warning => "RabbitMQ domain (params.rmq_domain) not specified.");
  }

  # No specific data to return for post-deploy
  return $self->done(1);
}

1;
