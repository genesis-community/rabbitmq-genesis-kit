#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::New::RabbitMQ v2.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis;
use Genesis::UI qw(prompt_for prompt_for_boolean);

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{features} = [];
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Prompt for broker usage
  my $use_broker;
  prompt_for('use_broker', 'boolean',
    'Would you like to deploy the multitenant service broker in front of this RabbitMQ?',
    \$use_broker);

  # Prompt for broker domain if broker is used
  my $broker_domain;
  if ($use_broker) {
    prompt_for('broker_domain', 'line',
      'What hostname will the broker be reachable at (e.g. rmq-broker.mydomain.com)?',
      \$broker_domain);
  }

  # Prompt for RabbitMQ domain
  my $rmq_domain;
  prompt_for('rmq_domain', 'line',
    'What hostname will the RabbitMQ and RMQ Management Plugin be reachable at (e.g. rmq.mydomain.com)?',
    \$rmq_domain);

  # Create environment file
  my $env_file = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";
  open my $fh, ">>", $env_file or die "Cannot open $env_file for writing: $!";

  print $fh "kit:\n";
  print $fh "  name:    $ENV{GENESIS_KIT_NAME}\n";
  print $fh "  version: $ENV{GENESIS_KIT_VERSION}\n";
  print $fh "  features:\n";
  print $fh "    - (( replace ))\n";

  if ($use_broker) {
    print $fh "    - broker\n";
  }

  print $fh "genesis:\n";
  print $fh "  env:   $ENV{GENESIS_ENVIRONMENT}\n";
  print $fh "  vault: $ENV{GENESIS_VAULT_PREFIX}\n";

  print $fh "params:\n";
  print $fh "  rmq_domain: $rmq_domain\n";

  if ($use_broker) {
    print $fh "  broker_domain: $broker_domain\n";
  }

  close $fh;

  # Offer environment editor
  $self->_offer_environment_editor();

  return $self->done(1);
}

sub _offer_environment_editor {
  my ($self) = @_;
  my ($out, $rc, $err) = run({ interactive => 1 }, 'offer_environment_editor');
  if ($rc != 0) {
    $self->env->notify(warning => "Failed to run environment editor: $err");
  }
}

1;
