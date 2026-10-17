# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::Blueprint::RabbitMQ;

use v5.20;
use warnings;

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{files} = [];
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_; # $self is the same as $blueprint

  # Validate features
  $self->validate_features(valid_features => [qw(
    broker metrics-emitter no-rmq-tls no-mgmt-tls no-broker-tls
    external-rmq-lb route-registrar nats-tls stomp mqtt
    provided-rmq-cert provided-mgmt-cert provided-broker-cert
    prometheus no-prometheus-tls resolute
    +rmq-tls +mgmt-tls +broker-tls
  )]);

  # The old ha-mode policy was the only consumer of ha_sync_mode.
  if (defined($self->env->lookup('params.ha_sync_mode', undef))) {
    $self->env->notify(warning =>
      "The #c{params.ha_sync_mode} parameter is ignored.  It only fed the ".
      "ha-mode policy that RabbitMQ 4.x cannot use, and the kit no longer ".
      "sets that policy.  Remove it.  To set an operator policy on the ".
      "broker's vhosts, use #c{params.operator_policy_enabled}, ".
      "#c{params.operator_policy_name}, #c{params.operator_policy_definition}, ".
      "and #c{params.operator_policy_priority}."
    );
  }

  # Base manifests
  $self->add_files(qw(
    manifests/base.yml
    manifests/server.yml
    manifests/releases/cf-rabbitmq.yml
    manifests/releases/bpm.yml
    manifests/releases/haproxy.yml
  ));

  # Broker feature
  if ($self->want_feature("broker")) {
    $self->env->notify(warning =>
      "RabbitMQ 4.x removed classic queue mirroring, so the broker's default ".
      "operator policy, which set ha-mode, is turned off.  To have the broker ".
      "set a policy on the vhosts it creates, set #c{params.operator_policy_enabled} ".
      "and give #c{params.operator_policy_definition} a JSON definition that ".
      "RabbitMQ 4.x accepts, such as {\"dead-letter-exchange\":\"dlx\"}."
    );

    $self->add_files(qw(
      manifests/broker.yml
      manifests/releases/cf-rabbitmq-multitenant-broker.yml
      manifests/releases/cf-rabbitmq-smoke-tests.yml
      manifests/releases/cf-cli.yml
    ));

    # Broker TLS
    if (!$self->want_feature("no-broker-tls")) {
      $self->add_files(qw(
        manifests/addons/broker-tls.yml
      ));
    }

    # Route registrar
    if ($self->want_feature("route-registrar")) {
      $self->add_files(qw(
        manifests/addons/route-registrar.yml
        manifests/releases/routing.yml
        manifests/releases/bosh-dns-alias.yml
      ));

      if ($self->want_feature("no-broker-tls")) {
        $self->add_files(qw(
          manifests/addons/broker-no-tls-route-registrar.yml
        ));
      } elsif ($self->want_feature("provided-broker-cert")) {
        bail("Cannot have no-broker-tls and provided-broker-cert features");
      }
    }

    # NATS TLS
    if ($self->want_feature("nats-tls")) {
      if (!$self->want_feature("route-registrar")) {
        bail("Cannot have nats-tls feature without route-registrar feature");
      }

      $self->add_files(qw(
        manifests/addons/nats-tls.yml
      ));
    }

    # Metrics emitter
    if ($self->want_feature("metrics-emitter")) {
      $self->add_files(qw(
        manifests/addons/metrics-emitter.yml
        manifests/releases/rabbitmq-metrics-emitter.yml
        manifests/releases/loggregator-agent.yml
      ));
    }
  }

  # MQTT
  if ($self->want_feature("mqtt")) {
    $self->add_files(qw(
      manifests/addons/mqtt.yml
    ));
  }

  # STOMP
  if ($self->want_feature("stomp")) {
    $self->add_files(qw(
      manifests/addons/stomp.yml
    ));
  }

  # Prometheus
  if ($self->want_feature("prometheus")) {
    $self->add_files(qw(
      manifests/addons/prometheus.yml
    ));

    # The rabbitmq-server job opens the plugin's own TLS listener on port
    # 15691 whenever management TLS is on, using the management certificate,
    # so the kit adds nothing for TLS.  A haproxy sidecar bound to the same
    # port makes the node crash at boot with eaddrinuse.  The no-prometheus-tls
    # feature is still accepted, but the job has no property that closes the
    # listener, so it changes nothing.
  }

  if ($self->want_feature("no-prometheus-tls")) {
    $self->env->notify(warning =>
      "The #c{no-prometheus-tls} feature has no effect.  The rabbitmq-server ".
      "job opens the Prometheus TLS listener on port 15691 with the management ".
      "certificate whenever management TLS is on, and it has no property to ".
      "close that listener.  To serve metrics without TLS, scrape plain HTTP ".
      "port 15692, or use #c{no-mgmt-tls}, which also turns off management TLS."
    );
  }

  # RabbitMQ TLS
  my $smoke_tests_removed = 0;
  if ($self->want_feature("no-rmq-tls")) {
    $self->add_files(qw(
      manifests/addons/no-rmq-tls.yml
    ));

    if ($self->want_feature("provided-rmq-cert")) {
      bail("Cannot have no-rmq-tls and provided-rmq-cert features");
    }

    if (!$self->want_feature("no-mgmt-tls")) {
      $self->add_files(qw(
        manifests/addons/no-rmq-tls-smoke-tests.yml
      ));
      $smoke_tests_removed = 1;
    }
  }

  # A provided management certificate cannot carry the rabbitmq-mgmt name that
  # the colocated smoke-tests job verifies, so the job is removed.  Both
  # addons remove the same job, and removing it twice is an error, so the
  # second one is skipped when the no-rmq-tls addon has already done it.
  if ($self->want_feature("provided-mgmt-cert") && !$smoke_tests_removed) {
    $self->add_files(qw(
      manifests/addons/provided-mgmt-cert-smoke-tests.yml
    ));
  }

  # Management TLS
  if ($self->want_feature("no-mgmt-tls")) {
    $self->add_files(qw(
      manifests/addons/no-mgmt-tls.yml
    ));

    # The broker builds http_api_uri from its management domain with an https
    # scheme unless told otherwise, and this deployment's management
    # listener is plain HTTP.
    if ($self->want_feature("broker")) {
      $self->add_files(qw(
        manifests/addons/no-mgmt-tls-broker.yml
      ));
    }

    if ($self->want_feature("route-registrar")) {
      $self->add_files(qw(
        manifests/addons/no-mgmt-tls-route-registrar.yml
        manifests/releases/routing.yml
        manifests/releases/bosh-dns-alias.yml
      ));
    }

    if ($self->want_feature("provided-mgmt-cert")) {
      bail("Cannot have no-mgmt-tls and provided-mgmt-cert features");
    }
  }

  # External RabbitMQ Load Balancer
  if ($self->want_feature("external-rmq-lb")) {
    $self->add_files(qw(
      manifests/addons/external-rmq-lb.yml
    ));

    if ($self->want_feature("broker")) {
      $self->add_files(qw(
        manifests/addons/external-rmq-lb-with-broker.yml
      ));
    }

    if ($self->want_feature("route-registrar")) {
      $self->add_files(qw(
        manifests/addons/external-rmq-lb-route-registrar.yml
        manifests/releases/routing.yml
        manifests/releases/bosh-dns-alias.yml
      ));
    }
  }

  $self->_process_static_ips;
  $self->_process_resolute;

  return $self->done();
}

# _process_static_ips - Literal static IPs for haproxy and the broker {{{
# The haproxy and broker networks use the static_ips operator by default, which
# cannot resolve the dotted network names of a Genesis 3 named cloud config.
# Setting params.proxy_static_ip or params.broker_static_ip swaps the operator
# for a literal address.  Each of those instance groups runs one instance, so
# each parameter takes a single IPv4 address, not a list.
sub _process_static_ips {
  my ($self) = @_;

  my %fragments = (
    proxy_static_ip  => 'manifests/proxy-static-ip.yml',
    broker_static_ip => 'manifests/broker-static-ip.yml',
  );

  my %ips;
  foreach my $param (qw(proxy_static_ip broker_static_ip)) {
    my $ip = $self->env->lookup("params.$param", undef);
    next unless defined $ip;

    my $valid = !ref($ip) && $ip =~ /^(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})$/
      && !grep { $_ > 255 } ($1, $2, $3, $4);
    bail(
      "The #c{params.%s} parameter must be a single IPv4 address, such as " .
      "10.0.0.16, because that instance group runs one instance.  Found #R{%s}.",
      $param, (ref($ip) ? 'a non-scalar value' : $ip)
    ) unless $valid;

    $ips{$param} = $ip;
  }

  # The external load balancer feature removes the haproxy instance group.  The
  # proxy fragment would merge a new haproxy group back in that holds only a
  # name and a network, which BOSH rejects, so refuse the combination.
  bail(
    "The #c{external-rmq-lb} feature removes the HAProxy instance group, so " .
    "#c{params.proxy_static_ip} (#R{%s}) has nothing to apply to.  " .
    "Remove #c{params.proxy_static_ip} or the #c{external-rmq-lb} feature.",
    $ips{proxy_static_ip}
  ) if defined($ips{proxy_static_ip}) && $self->want_feature('external-rmq-lb');

  # The two instance groups would claim the same address, and BOSH only finds
  # the conflict late in the deploy.  The broker address is only applied when
  # the broker feature is on, so it only conflicts then.
  bail(
    "The #c{params.proxy_static_ip} and #c{params.broker_static_ip} " .
    "parameters are both #R{%s}.  The HAProxy VM and the broker VM need " .
    "different addresses.",
    $ips{proxy_static_ip}
  ) if defined($ips{proxy_static_ip}) && defined($ips{broker_static_ip})
    && $ips{proxy_static_ip} eq $ips{broker_static_ip}
    && $self->want_feature('broker');

  foreach my $param (qw(proxy_static_ip broker_static_ip)) {
    next unless defined $ips{$param};

    # The broker group only exists with the broker feature, so the broker
    # address is validated but only applied when the feature is on.
    next if $param eq 'broker_static_ip' && !$self->want_feature('broker');
    $self->add_files($fragments{$param});
  }
}
# }}}

# _process_resolute - Opt-in ubuntu-resolute stemcell support {{{
# Called after every other fragment is added so that it overrides the
# stemcell os default (ubuntu-jammy) and the bpm release pin.
sub _process_resolute {
  my ($self) = @_;

  if ($self->want_feature('resolute')) {
    my $stemcell_os = $self->env->lookup('params.stemcell_os', 'ubuntu-resolute');
    bail(
      "The #c{resolute} feature sets the stemcell os to ubuntu-resolute, but " .
      "the environment sets #c{params.stemcell_os} to #R{%s}.  " .
      "Remove that parameter.", $stemcell_os
    ) if $stemcell_os ne 'ubuntu-resolute';

    # The pinned routing and metrics emitter releases have not been proven on
    # resolute, so refuse them rather than render a deployment that may fail.
    my @unproven = grep { $self->want_feature($_) } qw(route-registrar metrics-emitter);
    bail(
      "The #c{resolute} feature cannot be combined with the #R{%s} %s, " .
      "because the releases pinned for %s have not been proven on " .
      "ubuntu-resolute.  Remove %s or the #c{resolute} feature.",
      join(', ', @unproven),
      (@unproven == 1 ? 'feature' : 'features'),
      (@unproven == 1 ? 'it' : 'them'),
      (@unproven == 1 ? 'it' : 'them')
    ) if @unproven;

    $self->add_files('manifests/resolute.yml');
    # bpm runs on every instance group, and bpm releases older than 1.4.41 do
    # not compile on resolute.
    $self->add_files('manifests/releases/bpm-resolute.yml');
    # The haproxy package in releases before 16.3.0+3.2.12 bundles a socat
    # that does not compile on resolute, and the broker TLS addon runs the
    # haproxy job.
    $self->add_files('manifests/releases/haproxy-resolute.yml');
  } elsif ($self->env->lookup('params.stemcell_os', 'ubuntu-jammy') eq 'ubuntu-resolute') {
    bail(
      "The environment sets #c{params.stemcell_os} to ubuntu-resolute " .
      "without the #c{resolute} feature.  Enable the feature and remove " .
      "that parameter."
    );
  }
}
# }}}

1;
