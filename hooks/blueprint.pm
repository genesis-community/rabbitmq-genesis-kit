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
    prometheus no-prometheus-tls
    +rmq-tls +mgmt-tls +broker-tls
  )]);

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
      "The 'broker' feature (CF multitenant service broker) is not yet ".
      "validated against RabbitMQ 4.x. Classic queue mirroring was removed ".
      "in RabbitMQ 4.x, so the broker's ha-mode policies are invalid on ".
      "this release. Proceed only if you understand this risk."
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

    if (!$self->want_feature("no-prometheus-tls")) {
      $self->add_files(qw(
        manifests/addons/prometheus-tls.yml
      ));
    }
  }

  # RabbitMQ TLS
  if ($self->want_feature("no-rmq-tls")) {
    $self->add_files(qw(
      manifests/addons/no-rmq-tls.yml
    ));

    if ($self->want_feature("provided-rmq-cert")) {
      bail("Cannot have no-rmq-tls and provided-rmq-cert features");
    }
  }

  # Management TLS
  if ($self->want_feature("no-mgmt-tls")) {
    $self->add_files(qw(
      manifests/addons/no-mgmt-tls.yml
    ));

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

  return $self->done();
}

1;
