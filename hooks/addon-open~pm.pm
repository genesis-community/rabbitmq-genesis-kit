#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::RabbitMQ::Open v2.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";
use File::Basename qw/basename/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Open the RabbitMQ Management UI in a web browser (macOS & Linux only).\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my $vault_prefix = $ENV{GENESIS_VAULT_PREFIX};

  my $cmd = $self->get_command_for_os();
  unless ($cmd && `command -v $cmd 2>/dev/null`) {
    $env->notify("The 'open' addon script only works on macOS and Linux, currently.");
    return 0;
  }

  # Get exodus data
  my $exodus_data = $env->exodus_lookup('.');
  my $url = $exodus_data->{management_url};
  my $username = $exodus_data->{management_username} || 'admin';

  # Get password from vault
  my $password = $self->vault->get("secret/$vault_prefix/admin:password");

  unless ($url) {
    $env->notify(error => "Could not find management URL in exodus data");
    return 0;
  }

  unless ($password) {
    $env->notify(error => "Could not find admin password in vault");
    return 0;
  }

  $env->notify(
    "Opening RabbitMQ Management UI...\n\n".
    "Here's the credentials you'll need to sign in:\n\n".
    "\tusername: $username\n".
    "\tpassword: $password\n"
  );

  system($cmd, "https://$url");
  return $self->done();
}

sub get_command_for_os {
  my ($self) = @_;
  my $uname = `uname`;
  chomp($uname);

  if ($uname eq "Linux") {
    return "xdg-open";
  } elsif ($uname eq "Darwin") {
    return "open";
  } else {
    return undef;
  }
}

1;
