#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Info::RabbitMQ v2.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/bail info/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Get RabbitMQ environment info from exodus data
  my $exodus_data = $self->exodus_data();
  my $missing = "#RI{missing}";

  # Display RabbitMQ Management UI information
  info("\n#u{RabbitMQ Management UI}\n".
    "\tURL:      #C{%s}\n".
    "\tUsername: #C{%s}\n".
    "\tPassword: #C{%s}\n",
    $exodus_data->{management_url} // $missing,
    $exodus_data->{management_username} // $missing,
    $exodus_data->{management_password} // $missing);

  # Display Service Broker information if broker feature is active
  if ($self->env->has_feature('broker')) {
    info("\n#u{Service Broker}\n".
      "\tURL:          #C{%s}\n".
      "\tUsername:     #C{%s}\n".
      "\tPassword:     #C{%s}\n".
      "\tBroker Name:  #C{%s}\n".
      "\tService Name: #C{%s}\n",
      $exodus_data->{broker_url} // $missing,
      $exodus_data->{broker_username} // $missing,
      $exodus_data->{broker_password} // $missing,
      $exodus_data->{broker_name} // $missing,
      $exodus_data->{service_name} // $missing);
  }

  return $self->done();
}

1;
