# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
# NOTE: this file is not a Genesis-dispatched hook (Genesis loads hooks/check.pm
# for the "check" hook). It predates hooks/pre-deploy.pm, which now performs
# the same rmq_domain/broker_domain checks. Package renamed to stop colliding
# with hooks/check.pm's Genesis::Hook::Check::RabbitMQ; kept for reference.
package Genesis::Hook::RabbitMQ::LegacyDomainCheck;

use v5.20;
use warnings; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/info/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->{ok} = 1; # Start assuming all checks will pass
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Check if RabbitMQ domain is specified
  my $rmq_domain = $self->env->lookup('params.rmq_domain');
  if (!$rmq_domain) {
    $self->env->notify(error => "RabbitMQ domain (params.rmq_domain) is not specified");
    $self->{ok} = 0;
  }

  # Check if broker domain is specified when broker feature is active
  if ($self->env->has_feature('broker')) {
    my $broker_domain = $self->env->lookup('params.broker_domain');
    if (!$broker_domain) {
      $self->env->notify(error => "Broker domain (params.broker_domain) is not specified, but broker feature is active");
      $self->{ok} = 0;
    }
  }

  # Return the final result
  if ($self->{ok}) {
    $self->env->notify(success => "environment files [#G{OK}]");
  } else {
    $self->env->notify(error => "environment files [#R{FAILED}]");
  }

  return $self->done($self->{ok});
}

1;
