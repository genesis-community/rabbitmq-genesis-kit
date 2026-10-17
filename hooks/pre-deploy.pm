# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::PreDeploy::RabbitMQ;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use Genesis qw/bail info run load_yaml/;
use JSON::PP ();

# The first cf-rabbitmq release that carries RabbitMQ 3.13 or newer.  Releases
# 484 to 613 carry 3.12 at most, and release 614 carries only 3.13 and 4.2, so a
# deployed release older than this one cannot be running 3.13 or newer.
use constant FIRST_RELEASE_WITH_RABBITMQ_3_13 => 614;

# Genesis ships no Genesis::Hook::PreDeploy base class; pre-deploy module hooks
# derive straight from Genesis::Hook.
use parent qw(Genesis::Hook);
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

  # A cluster older than RabbitMQ 3.13 cannot move to the 4.2 this kit deploys,
  # so stop before BOSH touches it.
  $self->check_deployed_rabbitmq_version;

  # Check if required credentials are present in vault
  my $vault_prefix = $ENV{GENESIS_VAULT_PREFIX};

  # Check for admin credentials
  my $admin_password = $env->vault->get("$vault_prefix/admin:password");
  if (!$admin_password) {
    $env->notify(warning => "Admin password not found in vault. Will be generated during deployment.");
  }

  # For broker feature, check for broker credentials
  if ($env->has_feature('broker')) {
    my $broker_password = $env->vault->get("$vault_prefix/broker:password");
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

# check_deployed_rabbitmq_version - refuse to upgrade a cluster older than 3.13 {{{
# RabbitMQ cannot move from a release older than 3.13 straight to 4.2.  The 4.2
# nodes cannot start on the old data directory, and by then the deploy has
# already stopped the old cluster.  The check reads the manifest that BOSH holds
# for this environment's deployment.  With no deployment yet, there is nothing
# to protect and the check passes.
sub check_deployed_rabbitmq_version {
  my ($self) = @_;
  my $env = $self->env;

  my $skip = parse_boolean_param(
    scalar($env->lookup('params.skip_rabbitmq_upgrade_check', 0)),
    'params.skip_rabbitmq_upgrade_check'
  );
  if ($skip) {
    $env->notify(warning =>
      "Skipping the check for a deployed RabbitMQ older than 3.13, because ".
      "#c{params.skip_rabbitmq_upgrade_check} is set.  RabbitMQ 4.2 cannot ".
      "start on the data directory of a cluster older than 3.13."
    );
    return;
  }

  my $bosh = $env->with_bosh->bosh;
  my $deployment = $env->deployment_name;
  my $deployments = $bosh->deployments;
  unless (exists $deployments->{$deployment}) {
    info("  No deployment named #C{%s} exists yet, so there is no RabbitMQ to upgrade.", $deployment);
    return;
  }

  # Release versions as BOSH reports them, for a manifest that does not pin one.
  my %deployed_releases;
  for my $release (@{$deployments->{$deployment}{releases} || []}) {
    my ($name, $version) = split(m{/}, $release, 2);
    $deployed_releases{$name} //= $version if defined($name) && defined($version);
  }

  # The deployed manifest holds credentials, so only its parsed form is used and
  # nothing from it is printed.
  my ($yaml, $rc, $err) = $bosh->execute({stderr => 0}, 'manifest');
  bail(
    "Could not read the deployed manifest of #C{%s} to check which RabbitMQ it ".
    "runs: %s\nSet #c{params.skip_rabbitmq_upgrade_check} to #c{true} to deploy ".
    "without this check.",
    $deployment, ($err || 'bosh manifest failed')
  ) if $rc;

  my ($manifest, $yrc, $yerr) = load_yaml($yaml);
  bail(
    "Could not parse the deployed manifest of #C{%s}: %s\nSet ".
    "#c{params.skip_rabbitmq_upgrade_check} to #c{true} to deploy without this check.",
    $deployment, ($yerr || 'the manifest is not valid YAML')
  ) if $yrc || ref($manifest) ne 'HASH';

  my $result = assess_deployed_rabbitmq($manifest, \%deployed_releases);
  if ($result->{verdict} eq 'old') {
    bail(
      "The #C{%s} deployment runs RabbitMQ older than 3.13 (%s), and this kit ".
      "deploys RabbitMQ 4.2.  RabbitMQ cannot upgrade in place from a release ".
      "older than 3.13 to 4.2.  The new nodes fail to start on the old data ".
      "directory after the old cluster has stopped, which is an outage.\n\n".
      "Move to a new RabbitMQ 4.2 deployment instead, as the #M{Moving a ".
      "cluster older than RabbitMQ 3.13 to a new 4.2 cluster} part of the ".
      "#M{Upgrading to RabbitMQ 4.x} section of the kit MANUAL describes: ".
      "export the definitions from the old cluster, deploy this kit as a new ".
      "environment, import the definitions, and move the clients across.\n\n".
      "If you have already moved the cluster to 3.13 or newer, or you know the ".
      "deployment is being replaced, set #c{params.skip_rabbitmq_upgrade_check} ".
      "to #c{true} in the environment file.",
      $deployment, $result->{reason}
    );
  }
  if ($result->{verdict} eq 'unknown') {
    bail(
      "Could not tell which RabbitMQ the #C{%s} deployment runs (%s), so the ".
      "kit cannot confirm that a move to RabbitMQ 4.2 is safe.  RabbitMQ cannot ".
      "upgrade in place from a release older than 3.13 to 4.2.  Check the ".
      "running version, and set #c{params.skip_rabbitmq_upgrade_check} to ".
      "#c{true} once you know it is 3.13 or newer.",
      $deployment, $result->{reason}
    );
  }
  info("  Deployed RabbitMQ check [#G{OK}] (%s)", $result->{reason});
}
# }}}

# parse_boolean_param - read a boolean environment parameter {{{
# Accepts the YAML booleans and the strings Genesis users commonly write.  Any
# other value stops the deploy rather than being read as true or false.
sub parse_boolean_param {
  my ($value, $name) = @_;
  return 0 unless defined($value);
  return ($value ? 1 : 0) if ref($value) =~ /Boolean/;
  bail("The #c{%s} parameter must be true or false, not a list or a map.", $name)
    if ref($value);
  return 1 if $value =~ /^(?:true|yes|on|1)$/i;
  return 0 if $value =~ /^(?:false|no|off|0|)$/i;
  bail("The #c{%s} parameter must be true or false, found #R{%s}.", $name, $value);
}
# }}}

# assess_deployed_rabbitmq - decide whether a deployed manifest runs RabbitMQ 3.13 or newer {{{
# Takes the deployed manifest as a hash and a hash of release name to the
# release version BOSH reports.  Returns a hash with a verdict and a reason.
#   ok       every rabbitmq-server job runs 3.13 or newer
#   old      at least one rabbitmq-server job runs a release older than 3.13
#   unknown  the manifest does not say, and neither does BOSH
#   none     the manifest has no rabbitmq-server job
# The rabbitmq-server.version property decides first, when the manifest sets
# it.  Otherwise the version of the deployed cf-rabbitmq release decides, since
# each release defaults to the newest RabbitMQ it carries and releases older
# than 614 carry nothing newer than 3.12.
sub assess_deployed_rabbitmq {
  my ($manifest, $deployed_releases) = @_;
  $deployed_releases ||= {};

  my @jobs;
  for my $group (@{$manifest->{instance_groups} || []}) {
    next unless ref($group) eq 'HASH';
    for my $job (@{$group->{jobs} || []}) {
      push @jobs, [$group, $job]
        if ref($job) eq 'HASH' && ($job->{name} // '') eq 'rabbitmq-server';
    }
  }
  return {verdict => 'none', reason => 'the deployed manifest has no rabbitmq-server job'}
    unless @jobs;

  my (@old, @unknown, @ok);
  for my $pair (@jobs) {
    my ($group, $job) = @$pair;
    my $label = sprintf('instance group %s', $group->{name} // 'unnamed');

    # 1. The version property, from the job, its instance group, or the top level.
    my $property;
    for my $source ($job, $group, $manifest) {
      my $props = ref($source->{properties}) eq 'HASH' ? $source->{properties} : {};
      my $server = ref($props->{'rabbitmq-server'}) eq 'HASH' ? $props->{'rabbitmq-server'} : {};
      if (defined($server->{version}) && !ref($server->{version}) && $server->{version} ne '') {
        $property = $server->{version};
        last;
      }
    }
    if (defined $property) {
      my $old = rabbitmq_version_is_old($property);
      if (defined $old) {
        push @{$old ? \@old : \@ok}, sprintf(
          '%s sets rabbitmq-server.version to %s', $label, $property
        );
        next;
      }
    }

    # 2. The deployed cf-rabbitmq release.
    my $release_name = $job->{release} // 'cf-rabbitmq';
    my $release_version;
    for my $release (@{$manifest->{releases} || []}) {
      next unless ref($release) eq 'HASH' && ($release->{name} // '') eq $release_name;
      $release_version = $release->{version};
      last;
    }
    my $number = release_number($release_version);
    unless (defined $number) {
      # The manifest names no usable version (it may say latest), so use the one
      # BOSH reports for the deployment.
      $release_version = $deployed_releases->{$release_name};
      $number = release_number($release_version);
    }

    unless (defined $number) {
      push @unknown, sprintf(
        '%s sets no usable rabbitmq-server.version, and the version of its %s release is %s',
        $label, $release_name, defined($release_version) ? "\"$release_version\"" : 'not recorded'
      );
      next;
    }
    if ($number < FIRST_RELEASE_WITH_RABBITMQ_3_13) {
      push @old, sprintf(
        '%s runs %s release %s, and releases before %d carry RabbitMQ 3.12 at most',
        $label, $release_name, $release_version, FIRST_RELEASE_WITH_RABBITMQ_3_13
      );
    } else {
      push @ok, sprintf(
        '%s runs %s release %s, which defaults to RabbitMQ 3.13 or newer',
        $label, $release_name, $release_version
      );
    }
  }

  return {verdict => 'old',     reason => join('; ', @old)}     if @old;
  return {verdict => 'unknown', reason => join('; ', @unknown)} if @unknown;
  return {verdict => 'ok',      reason => join('; ', @ok)};
}
# }}}

# rabbitmq_version_is_old - true when a RabbitMQ version is older than 3.13 {{{
# Returns undef when the value is not a RabbitMQ version.  An unquoted 3.10 in
# YAML reads back as 3.1, which is older than 3.13 either way.
sub rabbitmq_version_is_old {
  my ($version) = @_;
  return undef unless defined($version) && $version =~ /^\s*v?(\d+)(?:\.(\d+))?/;
  my ($major, $minor) = ($1, $2 // 0);
  return ($major < 3 || ($major == 3 && $minor < 13)) ? 1 : 0;
}
# }}}

# release_number - the leading number of a BOSH release version {{{
# 483.0.0 and 616.0.0+dev.3 give 483 and 616.  Returns undef for latest and
# anything else that does not start with a number.
sub release_number {
  my ($version) = @_;
  return undef unless defined($version) && !ref($version) && $version =~ /^\s*v?(\d+)/;
  return $1 + 0;
}
# }}}

1;
