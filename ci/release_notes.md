## Improvements

* The kit has a new opt-in `resolute` feature for ubuntu-resolute stemcells. It sets the stemcell OS, uses a bpm release that runs on resolute, and refuses combinations it cannot support, such as `route-registrar` or `metrics-emitter` with `resolute`, a resolute stemcell without the feature, and the feature with a stemcell of another OS.

* The `proxy_static_ip` and `broker_static_ip` parameters set a literal address for the HAProxy and broker VMs. They exist for Genesis 3 named cloud configs, where network names are dotted and the `static_ips` operator cannot resolve them.

* The broker feature now pins the community fork of the broker release, `cloudfoundry-community/cf-rabbitmq-multitenant-broker-release`, on every stemcell. It replaces the pivotal-cf v107 pin, whose blobs return 403. The final release does not exist yet, so the kit pins the dev release `0+dev.1` with no URL or sha1. The release manifest holds a comment that shows where the URL and sha1 of `237.0.0+cfcommunity.1` go.

* The broker's smoke tests moved to cf-rabbitmq-smoke-tests 278.0.0, and the broker VM now runs the `cf-cli-8-linux` job from cf-cli 2.10.0. The 278 smoke tests log in with a UAA client, so the broker feature requires the new `cf_admin_client` and `cf_admin_client_secret` parameters.

* The broker's default operator policy is off. Its old `ha-mode` definition is invalid on RabbitMQ 4.x. The new `operator_policy_enabled`, `operator_policy_name`, `operator_policy_definition`, and `operator_policy_priority` parameters set a policy for anyone who wants one. They replace `ha_sync_mode`, which only fed the old definition.

## Bug fixes

* The colocated cf-rabbitmq smoke-tests job now points at the management TLS listener and its CA. The management server certificate now also covers `localhost` and `127.0.0.1`.

* `no-mgmt-tls` set the management port to 16572. It is 15672, and the value feeds the broker's management domain and the metrics emitter endpoint. The exodus management URL also follows the management scheme now, so it reads `http` under `no-mgmt-tls`.

* `no-rmq-tls` did not turn off the broker's `rabbitmq.ssl` property because of a misspelled path. It does now.

* With `no-rmq-tls` and management TLS on, the colocated smoke-tests job checked AMQPS on port 5671, which does not listen. The job has a single TLS switch for both listeners, so the kit now removes the job in that combination.

* The acceptance-tests errand failed with `curl: option --cacert: is badly used here` because the kit gave it no CA. The kit now sets the AMQP and management TLS flags and CAs for it, and `no-rmq-tls` and `no-mgmt-tls` switch the matching flag off. The job still connects to node addresses that the management certificate does not name, so its management checks need a change in the cf-rabbitmq release before they can pass against a TLS-only listener.

* The post-deploy hook no longer calls the base class `perform`, which raised an error after every successful deploy. Its message text was also corrected.

* The hooks resolve the Genesis library fallback correctly, and the post-deploy hook's `info` argument lists were fixed.
