#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PostDeploy::RabbitMQ v2.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/info/;
use parent qw(Genesis::Hook::PostDeploy);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

# Initialize the hook
sub init {
  my ($class, %ops) = @_;
  my $self = $class->SUPER::init(%ops);
  $self->check_minimum_genesis_version('3.1.0-rc.20');
  return $self;
}

# Main hook execution
sub perform {
  my ($self) = @_;

  # Base class has deploy_successful method to check if GENESIS_DEPLOY_RC == 0
  if ($self->deploy_successful) {
    info(
      "\nt#M{$ENV{GENESIS_ENVIRONMENT}} RabbitMQ deployed!\n".
      "\ntFor details about the deployment, run\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} info}\n".
      "\nTo open the RabbitMQ Management UI:\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do -- open}\n".
      "\nTo run smoke tests:\n".
      "\t#G{$ENV{GENESIS_CALL_ENV} do -- smoketest}\n".
    );

    # If broker feature is enabled
    if ($self->env->has_feature('broker')) {
      info(
        "\nTo register the broker with Cloud Foundry:\n".
        "\t#G{$ENV{GENESIS_CALL_ENV} do -- register-broker}\n".
        "\nTo deregister the broker from Cloud Foundry:\n".
        "\t#G{$ENV{GENESIS_CALL_ENV} do -- deregister-broker}\n".
      );
    }
  }

  # Call parent class methods if needed
  $self->SUPER::perform() if $self->can('SUPER::perform');

  # Mark the hook as completed successfully
  return $self->done();
}

1;
