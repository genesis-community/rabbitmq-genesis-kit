This is a major release. It moves the kit from cf-rabbitmq 483.0.0 with RabbitMQ 3.8 to cf-rabbitmq 616.0.0 with RabbitMQ 4.2 and Erlang 27, and it raises the Genesis floor to 3.1.0-rc.20. The kit version is now 1.0.0. Earlier published versions of this kit end at v0.5.2, so set `kit.version` to 1.0.0 in your environment files.

## Breaking changes and upgrade steps

Work through these steps in order when you upgrade an existing environment.

1. Move off classic mirrored queues before you deploy. RabbitMQ 4.x removed classic queue mirroring, and quorum queues are the default queue type. Migrate any classic mirrored queues to quorum queues first. The [Upgrading to RabbitMQ 4.x](../MANUAL.md#upgrading-to-rabbitmq-4x) section of the manual lists everything that changes for a cluster coming from 3.x.

2. Upgrade Genesis to 3.1.0-rc.20 or later, then set `kit.version` to 1.0.0 in each environment file.

3. Remove `ha_sync_mode` from your environment files. It only fed the `ha-mode` policy that RabbitMQ 4.x cannot use, so the kit now ignores it and prints a notice when it is set. If you want the broker to set an operator policy on the vhosts it creates, use the new `operator_policy_enabled`, `operator_policy_name`, `operator_policy_definition`, and `operator_policy_priority` parameters. The broker's default policy is off.

4. If you use the `broker` feature, create a UAA client for the broker smoke tests, with the `client_credentials` grant and the `cloud_controller.admin` authority. Set `params.cf_admin_client` to its name, then store its secret in Vault at `secret/<your/env>/rabbitmq/cf/admin-client` under the key `secret`. Running `genesis <env> add-secrets` prompts for the secret. The manifest will not build until the parameter is set, and `check-secrets` reports the secret as missing until it exists.

5. If you use the `broker` feature, make sure the Director already has the broker release that the kit pins. The kit now pins the community fork of the broker release, because the pivotal-cf v107 release no longer serves its blobs. Until the fork's first final release is cut, the pin is a dev release, `0+dev.4`, with no URL, so the Director has to hold it already.

6. Deploy the environment.

7. If you use the `prometheus` feature, update your scrapers after the deploy. The kit no longer runs a haproxy sidecar in front of port 15691, so `https://<rmq_domain>:15691/metrics` no longer exists. Each RabbitMQ node serves port 15691 itself with the management certificate and port 15692 over plain HTTP. HAProxy does not forward either port, so scrape every node address as its own target. Trust the management CA (`/mgmt/certs/ca`) instead of the RabbitMQ CA, and set `server_name: rabbitmq-mgmt` in the scraper's TLS configuration, because the node addresses are not names in the management certificate. The `no-prometheus-tls` feature is still accepted but has no effect, and the kit prints a notice when you use it.

The kit pins cf-rabbitmq 616.0.0. Its smoke-tests job and the acceptance-tests errand in 616.0.0 verify the management certificate by the name `rabbitmq-mgmt`, and they take their curl credentials from a file instead of the command line. The management certificate therefore no longer needs the `localhost` and `127.0.0.1` names, so the kit stops requesting them, and an upgrade does not require you to rotate the certificate. The kit pins `616.0.0+dev.2` with no URL until the final is cut, so the Director has to hold that dev release before you deploy, the same as for the broker release.

## Improvements

* The kit deploys RabbitMQ 4.2 with Erlang 27 from cf-rabbitmq 616.0.0. The `rabbitmq-server` and `rabbitmq-haproxy` jobs run under bpm, and the kit sets `features.use_dns_addresses` to `false` because RabbitMQ node names come from instance IP addresses.

* The kit has two test errands. The `smoke-tests` job is colocated on the `rmq-server` instance group and runs after every deploy. A separate `acceptance-tests` errand exercises AMQP, management, cluster, HAProxy, and plugin checks. The new `smoke-tests` and `acceptance-tests` addons run them, and the `mqtt`, `stomp`, and `prometheus` features add their plugins to the acceptance-tests plugin checks.

* The `smoke-tests` addon runs only the broker's errand, with `--instance rmq-broker`, because the colocated job has the same name. The post-deploy message suggests it only when the broker is on, and suggests the `acceptance-tests` addon otherwise.

* The acceptance-tests errand follows the management port, so it uses 15671 while management TLS is on.

* The kit supports the pve, stackit, azure, gcp, openstack, vsphere, and aws infrastructures, and its hooks are now Perl modules.

* The kit has a new opt-in `resolute` feature for ubuntu-resolute stemcells. It sets the stemcell OS, uses a bpm release that runs on resolute, pins haproxy-boshrelease 16.13.0+3.2.25 because the socat bundled in earlier haproxy releases does not compile on resolute, and refuses combinations it cannot support. Those are `route-registrar` or `metrics-emitter` with `resolute`, a resolute stemcell without the feature, and the feature with a stemcell of another OS. The broker runs on resolute, and a live test registered it with Cloud Foundry and bound an app to a service instance.

* The `proxy_static_ip` and `broker_static_ip` parameters set a literal address for the HAProxy and broker VMs. They exist for Genesis 3 named cloud configs, where network names are dotted and the `static_ips` operator cannot resolve them. The kit stops with an error if `proxy_static_ip` is set together with `external-rmq-lb`, or if both addresses are the same while the broker is on. The `proxy_static_ip` address is also added as an IP name on the RabbitMQ server and management certificates, and an existing environment needs `genesis <env> rotate-secrets --update-subjects -y rabbitmq/certs/server mgmt/certs/server` to pick it up.

* The broker feature pins the community fork of the broker release, `cloudfoundry-community/cf-rabbitmq-multitenant-broker-release`, on every stemcell. The broker's smoke tests moved to cf-rabbitmq-smoke-tests 278.0.0, and the broker VM runs the `cf-cli-8-linux` job from cf-cli 2.10.0. The 278 smoke tests log in with a UAA client, so the broker feature requires the `cf_admin_client` parameter and its provided secret.

* The broker's default operator policy is off, and the new `operator_policy_*` parameters set one.

* With `provided-mgmt-cert`, the kit removes the colocated `smoke-tests` job, because it verifies the management certificate by the name `rabbitmq-mgmt`, which a certificate from a public or corporate CA does not carry.

* The `mqtt` feature sets the cluster's default queue type to classic, so QoS 1 subscribes from clean-session clients work. The plugin declares an exclusive queue for those sessions without a queue type, and an exclusive queue cannot be a quorum queue. The feature keeps sessions with a non-zero expiry on quorum queues through `mqtt.durable_queue_type`. Queues declared without a type over any protocol are classic and unreplicated while the feature is on, and the [mqtt section of the manual](../MANUAL.md#mqtt) explains the trade-off.

## Bug fixes

* The `prometheus` feature no longer crashes RabbitMQ at boot when management TLS is on. The kit's haproxy sidecar bound the same port 15691 that the `rabbitmq-server` job opens itself, so the node died with `could_not_start_listener ... eaddrinuse`. The kit now drops the sidecar.

* `no-mgmt-tls` set the management port to 16572. It is 15672, and the value feeds the broker's management domain and the metrics emitter endpoint. The exodus management URL also follows the management scheme now, so it reads `http` under `no-mgmt-tls`.

* `no-rmq-tls` did not turn off the broker's `rabbitmq.ssl` property because of a misspelled path. It does now. With `no-rmq-tls` and management TLS on, the kit removes the colocated smoke-tests job, because that job has a single TLS switch for both listeners.

* The acceptance-tests errand failed with `curl: option --cacert: is badly used here` because the kit gave it no CA. The kit now sets the AMQP and management TLS flags and CAs for it, and `no-rmq-tls` and `no-mgmt-tls` switch the matching flag off. With cf-rabbitmq 616.0.0 the errand reaches the management API through the name `rabbitmq-mgmt`, which the management certificate carries, and its HAProxy checks use HTTPS when management TLS is on, so its management and HAProxy checks pass against a TLS-only listener.

* Service bindings from the `broker` feature advertised the management API at HTTP port 15672 even when management TLS was on, where nothing listens. With the broker release at `0+dev.4`, the `management` and `management+ssl` entries in a binding point at HTTPS port 15671 with `ssl` true when management TLS is on, and stay at HTTP port 15672 with `no-mgmt-tls`. The `http_api_uri` and `http_api_uris` entries are built from the management domain, and their scheme now comes from the broker's `management_api_scheme` property. It defaults to `https`, and `no-mgmt-tls` sets it to `http`, so the URIs match the plain listener. The `dashboard_url` entry stays on `https`.

* The post-deploy hook no longer calls the base class `perform`, which raised an error after every successful deploy. The hooks also resolve the Genesis library fallback correctly.
