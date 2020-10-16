# Software Updates

* RabbitMQ bumped to 312.0.0
* RabbitMQ Multitenant Broker bumped to 80.0.0
* RabbitMQ Smoke Tests bumped to 66.0.0
* bpm bumped to 1.1.9
* CF CLI bumped to 1.30.0
* Routing bumped to 0.207.0

# Improvements

* The management plugin API now defaults to serving TLS.
* If `external_rmq_lb` is enabled (thus causing no haproxy node to be deployed)
and also `route-registrar` is enabled, the route-registrar jobs will be moved
to the rmq-server nodes instead of just not being deployed at all.

# New Features

* `provided-rmq-cert` - Provide your own certificate for the RMQ server nodes
instead of relying on Genesis-generated self-signed certs.
* `no-mgmt-tls` - Turns off TLS for the management plugin API, instead serving
plain HTTP.
* `mqtt` - Turns on the rabbit_mqtt plugin.
* `stomp` - Turns on the rabbit_stomp plugin.
* `metrics-emitter` - Colocates a RabbitMQ Metrics Emitter on the service broker
which can send statistics about queue lengths to the CF Loggregator to be used
with the open source CF App Autoscaler.

# New Parameters

* `check_queue_sync` - Turns on a feature of the pre-stop script for RabbitMQ
in which the cluster will wait to shut down until all unsynced queues have been
synced.
* `ha_sync_mode` - (broker feature) The ha_sync_mode parameter configured with
vhosts created by the service broker. Defaults to manual.
* The incoming domain parameters were regulated to the following three:
  * `rmq_domain` - The domain of the RMQ cluster.
  * `mgmt_domain` - The domain of the management plugin API (defaults to the
  value of rmq_domain).
  * `broker_domain` - The domain of the service broker.

# Core Components 
 
| Release | Version | Release Date |
| ------- | ------- | ------------ | 
| CF RabbitMQ | [312.0.0](https://github.com/pivotal-cf/cf-rabbitmq-release/releases/tag/v312.0.0) | Jul 13, 2020 |
| CF RabbitMQ Multitenant Broker | [80.0.0](https://github.com/pivotal-cf/cf-rabbitmq-multitenant-broker-release/releases/tag/v80.0.0) | Sep 11, 2020 |
| CF RabbitMQ Smoke Tests | [66.0.0](https://github.com/pivotal-cf/cf-rabbitmq-smoke-tests-release/releases/tag/v66.0.0) | Sep 23, 2020 |
| bpm | [1.1.9](https://github.com/cloudfoundry/bpm-release/releases/tag/v1.1.9) | Aug 27, 2020 |
| CF CLI | [1.30.0](https://github.com/bosh-packages/cf-cli-release/releases/tag/v1.30.0) | Sep 9, 2020 |
| HAProxy | [10.1.0](https://github.com/cloudfoundry-incubator/haproxy-boshrelease/releases/tag/v10.1.0) | Apr 26, 2020 |
| Routing | [0.207.0](https://github.com/cloudfoundry/routing-release/releases/tag/0.207.0) | Sep 1, 2020 |
| RabbitMQ Metrics Emitter | [0.4.1](https://github.com/starkandwayne/rabbitmq-metrics-emitter-release/releases/tag/v0.4.1) | Oct 1, 2020 |
| Loggregator Agent | [3.9](https://github.com/cloudfoundry/loggregator-agent-release/releases/tag/v3.9) | Mar 15, 2019 | 