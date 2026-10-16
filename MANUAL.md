# RabbitMQ Genesis Kit Manual

The **RabbitMQ Genesis Kit** deploys a RabbitMQ cluster and, optionally, the CF RabbitMQ Multitenant Service Broker.

## Table of Contents

- [Overview](#overview)
- [Deployment Architecture](#deployment-architecture)
- [Base Parameters](#base-parameters)
  - [Literal Static IPs](#literal-static-ips)
- [Features](#features)
  - [Broker Integration](#broker-integration)
    - [`broker`](#broker)
    - [`no-broker-tls`](#no-broker-tls)
    - [`metrics-emitter`](#metrics-emitter)
  - [Cloud Foundry Integration](#cloud-foundry-integration)
    - [`route-registrar`](#route-registrar)
    - [`nats-tls`](#nats-tls)
  - [TLS Configuration](#tls-configuration)
    - [`no-rmq-tls`](#no-rmq-tls)
    - [`no-mgmt-tls`](#no-mgmt-tls)
    - [`provided-rmq-cert`](#provided-rmq-cert)
    - [`provided-mgmt-cert`](#provided-mgmt-cert)
    - [`provided-broker-cert`](#provided-broker-cert)
  - [Load Balancing](#load-balancing)
    - [`external-rmq-lb`](#external-rmq-lb)
  - [Protocol Support](#protocol-support)
    - [`mqtt`](#mqtt)
    - [`stomp`](#stomp)
  - [Monitoring](#monitoring)
    - [`prometheus`](#prometheus)
    - [`no-prometheus-tls`](#no-prometheus-tls)
  - [Stemcell](#stemcell)
    - [`resolute`](#resolute)
- [Feature Compatibility Matrix](#feature-compatibility-matrix)
- [Available Addons](#available-addons)
- [Security Considerations](#security-considerations)
- [Performance Tuning](#performance-tuning)
- [Upgrading](#upgrading)
- [Troubleshooting](#troubleshooting)
- [Monitoring and Metrics](#monitoring-and-metrics)

## Overview

The RabbitMQ Genesis Kit provides a production-ready RabbitMQ cluster deployment with optional integration to Cloud Foundry. It leverages the power of BOSH to manage the lifecycle of the RabbitMQ service, including deployment, updates, and recovery from failure scenarios. The kit deploys RabbitMQ 4.2 (paired with Erlang 27) using the `cf-rabbitmq` BOSH release.

## Deployment Architecture

The standard RabbitMQ deployment architecture consists of:

1. **RabbitMQ Server Nodes**: Multiple RabbitMQ server instances forming a cluster for high availability.
2. **HAProxy Layer**: A proxying layer to provide load balancing across the cluster nodes (unless using external load balancing).
3. **Service Broker** (optional): When integrating with Cloud Foundry, a service broker that manages RabbitMQ service instances.
4. **Process Supervision**: The `rabbitmq-server` and `rabbitmq-haproxy` jobs run under `bpm` (BOSH Process Manager). A `bpm` job is colocated on the `rmq-server` and `haproxy` instance groups to supervise them.
5. **Test Errands**: A `smoke-tests` job is colocated on the `rmq-server` instance group, and a separate `acceptance-tests` errand instance group exercises AMQP, management, cluster, HAProxy, and plugin checks against the deployed cluster.

The kit sets `features.use_dns_addresses: false` and this is not user-configurable. RabbitMQ derives its node name from the instance IP address and ships a static `erl_inetrc`; bosh-dns hostnames don't resolve for those node names and break cluster formation, so the kit keeps IP-based addressing.

The deployment includes these key components:

```
                      ┌─────────────┐
                      │   External  │
                      │   Clients   │
                      └──────┬──────┘
                             │
                             ▼
┌─────────────────────────────────────────────────┐
│                   HAProxy                       │ (Optional with external-rmq-lb)
└──────────┬───────────────┬──────────────┬───────┘
           │               │              │
           ▼               ▼              ▼
┌─────────────────┐ ┌────────────────┐ ┌────────────────┐
│ RabbitMQ Node 1 │ │ RabbitMQ Node 2│ │ RabbitMQ Node N│
└─────────────────┘ └────────────────┘ └────────────────┘
           ▲                                   ▲
           │                                   │
           └───────────────────────────────────┘
                Quorum Queue Replication
                  Clustered Management

      ┌───────────────┐  (Optional)
      │ Service Broker│ ◄─────► Cloud Foundry
      └───────────────┘
```

## Base Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `rmq_domain` | **REQUIRED** - The domain that the AMQP/MQTT/Stomp APIs will be located. If not using DNS, set this to the static IP of the RabbitMQ proxy (first static IP in the network). Do not include scheme or port. | *(No default)* |
| `mgmt_domain` | The domain for the RabbitMQ Management API. | `<value of rmq_domain>` |
| `rmq_instances` | The number of RabbitMQ nodes in the cluster. | `3` |
| `availability_zones` | The AZs that VMs will be deployed into. | `[z1]` |
| `server_network` | The network that the RabbitMQ server VMs will be deployed in. | `rabbitmq` |
| `proxy_network` | The network that HAProxy will be deployed in. Must be accessible to RabbitMQ users and the broker's network (if deploying with broker). | `rabbitmq` |
| `server_vm_type` | The VM type for RabbitMQ server VMs. | `rabbitmq` |
| `proxy_static_ip` | A literal static IPv4 address for the HAProxy VM. Use it with a Genesis 3 named cloud config, where network names are dotted. The address is also added as an IP subject alternative name on the RabbitMQ server certificate and the management server certificate, so clients that connect to HAProxy by IP can verify the certificate. See [Literal Static IPs](#literal-static-ips). | *(Unset, the first static IP of `proxy_network`)* |
| `proxy_vm_type` | The VM type for the HAProxy VM. | `small` |
| `server_disk_type` | The disk type for RabbitMQ server nodes. Used for cluster configuration, queue config, and durable queue data. | `rabbitmq` |
| `stemcell_os` | The OS of the stemcell to use. | `ubuntu-jammy` |
| `stemcell_version` | The version of the stemcell to use. | `latest` |
| `check_queue_sync` | If true, pre-stop script will wait until quorum queues are synced before shutting down. RabbitMQ 4.x removed classic queue mirroring, so this check now applies to quorum queue sync only. | `false` |

### Literal Static IPs

By default the kit asks BOSH for the first static IP in the proxy network for HAProxy, and the second static IP in the broker network for the broker. That lookup breaks on a Genesis 3 named cloud config, because those cloud configs give networks dotted names such as `ocfp-lab-example-ocf.rabbitmq.net-rabbitmq`, and the lookup splits the name at the dots and then fails to find the network.

In that situation, set `params.proxy_static_ip` to give HAProxy a literal address, and set `params.broker_static_ip` to do the same for the broker when the `broker` feature is on. Each parameter takes a single IPv4 address, because HAProxy and the broker each run one instance, and the kit stops with an error if the value is a list or anything other than a dotted IPv4 address. The address you choose must come from the static range of the network that the instance group uses, and the two addresses must differ from each other. The kit stops with an error if both are set to the same address while the `broker` feature is on, and it also stops if `params.proxy_static_ip` is set together with `external-rmq-lb`, because that feature removes the HAProxy VM and the address would have nothing to apply to. When you leave a parameter unset, the manifest is the same as it was before the parameter existed.

Because HAProxy fronts both the AMQPS and management listeners, `params.proxy_static_ip` also becomes an IP subject alternative name on the RabbitMQ server certificate (`rabbitmq/certs/server`) and the management server certificate (`mgmt/certs/server`). A client that connects to HAProxy by that IP can then verify the certificate hostname. When the parameter is unset, both certificates carry the same names as before. Genesis keeps the subject of an existing certificate when it rotates, so an environment that already has these certificates needs them regenerated after you set the parameter:

```
genesis <env> rotate-secrets --update-subjects -y rabbitmq/certs/server mgmt/certs/server
```

Naming the two paths keeps the rotation from touching any other secret. Deploy afterward to roll the new certificates out.

```yaml
params:
  proxy_network:    ocfp-lab-example-ocf.rabbitmq.net-rabbitmq
  proxy_static_ip:  10.99.0.20
  broker_network:   ocfp-lab-example-ocf.rabbitmq.net-rabbitmq
  broker_static_ip: 10.99.0.21
```

### Example Configuration

```yaml
# Example base RabbitMQ configuration
---
deployment: rabbitmq-prod

params:
  rmq_domain: rabbitmq.example.com
  mgmt_domain: rabbitmq-mgmt.example.com
  rmq_instances: 5
  availability_zones: [z1, z2, z3]
  server_vm_type: large
  server_disk_type: large
  check_queue_sync: true
```

## Features

### Broker Integration

#### `broker`

Deploys the cf-rabbitmq-multitenant-broker to allow applications within Cloud Foundry to utilize the RabbitMQ cluster. The broker server listens on TCP port 4566 for HTTPS traffic.

**Status on RabbitMQ 4.x**: The `broker` feature remains selectable and deployable. It is not yet validated against RabbitMQ 4.x. RabbitMQ 4.x removed classic queue mirroring in favor of quorum queues as the default queue type, and the `ha-mode` operator policy the broker used to set by default targets classic mirrored queues, so it is invalid on this release. The kit now turns that policy off by default (see `operator_policy_enabled` below). Deploying with `broker` on RabbitMQ 4.x still triggers a warning; proceed only if you understand this risk. Validation against quorum queues is planned follow-up work.

The kit pins the community fork of the broker release, `cloudfoundry-community/cf-rabbitmq-multitenant-broker-release`, on every stemcell. The pivotal-cf v107 release it replaces no longer serves its blobs. Until the fork's first final release is cut, the kit pins the dev release `0+dev.1`, which must already be on the Director. The comment in `manifests/releases/cf-rabbitmq-multitenant-broker.yml` shows where the final's URL and sha1 go.

The broker smoke tests use cf-rabbitmq-smoke-tests 278.0.0 with the `cf-cli-8-linux` job from cf-cli 2.10.0. That release logs in to Cloud Foundry with a UAA client, so the broker feature needs the `cf_admin_client` parameter and its provided secret, both described below.

##### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `broker_domain` | **REQUIRED** - The domain for the RabbitMQ CF Broker. Used to populate SANs on the certificate. | *(No default)* |
| `broker_username` | The username that the service broker will accept for authentication. | `broker` |
| `broker_network` | The network for the RabbitMQ Multitenant Broker. Must be reachable by CF Cloud Controller or GoRouters if using route-registrar. | `rabbitmq` |
| `broker_static_ip` | A literal static IPv4 address for the broker VM. Use it with a Genesis 3 named cloud config, where network names are dotted. The address is also added as an IP subject alternative name on the RabbitMQ server certificate and the management server certificate, so clients that connect to HAProxy by IP can verify the certificate. See [Literal Static IPs](#literal-static-ips). | *(Unset, the second static IP of `broker_network`)* |
| `broker_vm_type` | The VM type for the broker VM. | `small` |
| `broker_name` | The name of the broker as registered with Cloud Foundry. | `p-rabbitmq` |
| `service_name` | The name of the service exposed in the CF marketplace. | `p-rabbitmq` |
| `cf_admin_client` | **REQUIRED** - The name of a UAA client for the smoke tests to log in to Cloud Foundry. It needs the `client_credentials` grant and the `cloud_controller.admin` authority. The client's secret is a provided secret, described below. | *(No default)* |
| `operator_policy_enabled` | Whether the broker sets an operator policy on the vhosts it creates. | `false` |
| `operator_policy_name` | The name of that policy. | `operator_set_policy` |
| `operator_policy_definition` | The policy definition as a JSON string. It must be valid on RabbitMQ 4.x, so `ha-mode` keys are rejected. | `{}` |
| `operator_policy_priority` | The priority of that policy. | `50` |

The secret of the `cf_admin_client` UAA client is not a parameter, so it never appears in the environment file. The `broker` feature declares it as a provided secret, and you populate it at this path:

* `secret/<your/env>/rabbitmq/cf/admin-client:secret`

`genesis <env> add-secrets` prompts for the value, and `genesis <env> check-secrets` reports it missing until it exists.

##### Example Configuration

```yaml
# Example broker configuration
---
features:
  - broker

params:
  broker_domain: rabbitmq-broker.example.com
  broker_name: rabbitmq-service
  service_name: rabbitmq
  cf_admin_client: rabbitmq-smoke-tests
  # Optional. Off by default.
  operator_policy_enabled: true
  operator_policy_definition: '{"dead-letter-exchange":"dlx"}'
```

#### `no-broker-tls`

Depends on feature `broker`.

Disables TLS from the service broker. Only use this if you have `skip_verify` set to false on your Cloud Controller and cannot add the broker's CA to the trusted cert store of the Cloud Controller VMs.

#### `metrics-emitter`

Requires `broker` to be enabled. Co-locates a metrics emitter for RabbitMQ on the broker VM, which sends RabbitMQ metrics to the Cloud Foundry Loggregator.

##### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cf_skip_ssl_validation` | Whether to skip SSL validation when communicating with the CF API. | `false` |

##### Example Configuration

```yaml
# Enable metrics emission to CF
---
features:
  - broker
  - metrics-emitter

params:
  cf_skip_ssl_validation: false
```

### Cloud Foundry Integration

#### `route-registrar`

Depends on feature `broker`.

Registers routes with the Cloud Foundry NATS bus, enabling traffic forwarding to the broker and management API from the Cloud Foundry GoRouter. Relies on BOSH links, requiring the Cloud Foundry to be deployed by the same BOSH director.

##### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cf_deployment` | The name of the BOSH deployment containing your Cloud Foundry. | `<env-name>-cf` |
| `broker_domain` | The domain under which the broker will be registered with the GoRouter. | `rabbitmq-broker.<cf-system-domain>` |
| `mgmt_domain` | The domain under which the RabbitMQ management API will be registered with the GoRouter. | `rabbitmq-management.<cf-system-domain>` |

##### Example Configuration

```yaml
# Register routes with Cloud Foundry
---
features:
  - broker
  - route-registrar

params:
  cf_deployment: prod-cf
  broker_domain: rabbitmq-broker.apps.example.com
  mgmt_domain: rabbitmq-mgmt.apps.example.com
```

#### `nats-tls`

Depends on feature `route-registrar`.

Connects to the NATS bus over mutual TLS. Requires the nats-tls job to be deployed in your Cloud Foundry deployment.

##### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nats_client_cert` | **REQUIRED** - The certificate to present to NATS for Mutual TLS. | *(No default)* |
| `nats_client_key` | **REQUIRED** - The certificate private key to use with NATS for Mutual TLS. | *(No default)* |

##### Example Configuration

```yaml
# Enable NATS TLS for route registration
---
features:
  - broker
  - route-registrar
  - nats-tls

params:
  nats_client_cert: |
    -----BEGIN CERTIFICATE-----
    MIIEhDCCA2ygAwIBAgIQQhrxmuMvxt+FPXIhokpFRDANBgkqhkiG9w0BAQsFADA4
    ...certificate content...
    -----END CERTIFICATE-----
  nats_client_key: |
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA6Bf5unjVt5dXlziVkP3kpyR/T3WpC9c/MnYA1axK/pxj7j+X
    ...key content...
    -----END RSA PRIVATE KEY-----
```

### TLS Configuration

#### `no-rmq-tls`

Disables TLS communications to the RabbitMQ cluster and between RabbitMQ nodes.

The colocated `smoke-tests` job has a single TLS switch that moves both its AMQP listener check (port 5672 or 5671) and its management API check (HTTP or HTTPS). With `no-rmq-tls` and management TLS both in play, no setting of that switch is correct, so the kit removes the colocated `smoke-tests` job unless `no-mgmt-tls` is also enabled. The `acceptance-tests` errand follows both settings separately.

#### `no-mgmt-tls`

Disables the TLS listener for the Management API on port 15671, and will instead listen for plaintext HTTP traffic on port 15672. The broker management domain, the metrics emitter endpoint, and the exodus management URL all follow that port and scheme.

#### `provided-rmq-cert`

Requires you to provide your own certificates for the RabbitMQ cluster instead of generating them. You must populate:

* `secret/<your/env>/rabbitmq/rabbitmq/certs/server:certificate`
* `secret/<your/env>/rabbitmq/rabbitmq/certs/server:key`
* `secret/<your/env>/rabbitmq/rabbitmq/certs/ca:certificate`

#### `provided-mgmt-cert`

Requires you to provide your own certificates for the Management API instead of generating them. You must populate:

* `secret/<your/env>/rabbitmq/mgmt/certs/server:certificate`
* `secret/<your/env>/rabbitmq/mgmt/certs/server:key`
* `secret/<your/env>/rabbitmq/mgmt/certs/ca:certificate`

The colocated `smoke-tests` job runs after every deploy and connects to the management API at `127.0.0.1`, so it verifies the management certificate against the loopback address. A certificate from a public or corporate CA almost never carries a loopback IP name, so with this feature the kit removes the colocated `smoke-tests` job rather than let every deploy end in a failed post-deploy step. The `broker` smoke tests errand is unaffected, because it reaches Cloud Foundry and the broker and does not use the management certificate.

#### `provided-broker-cert`

Requires you to provide your own certificates for the Service Broker instead of generating them. You must populate:

* `secret/<your/env>/rabbitmq/broker/certs/server:certificate`
* `secret/<your/env>/rabbitmq/broker/certs/server:key`

### Load Balancing

#### `external-rmq-lb`

Removes the HAProxy VM and exposes the RabbitMQ nodes directly through a load balancer using a vm_extension defined in your cloud config. Because there is no HAProxy VM, do not set `proxy_static_ip` with this feature. The kit stops with an error if you do.

##### Important Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 1883 | MQTT | MQTT plain text |
| 5671 | AMQPS | AMQP over TLS |
| 5672 | AMQP | AMQP plain text |
| 8883 | MQTT over TLS | MQTT secured with TLS |
| 15671 | HTTPS | RabbitMQ Management over HTTPS |
| 15672 | HTTP | RabbitMQ Management over HTTP |
| 15674 | WebSTOMP | WebSocket STOMP |
| 61613 | STOMP | STOMP plain text |
| 61614 | STOMP over TLS | STOMP secured with TLS |

##### VM Extensions

* `rmq-loadbalancer` - Applied to each RabbitMQ server node to attach the VMs to the backend pool of a load balancer.

##### Example Configuration

```yaml
# Use external load balancer
---
features:
  - external-rmq-lb
```

### Protocol Support

#### `mqtt`

Enables the RabbitMQ MQTT plugin for MQTT protocol support.

##### Example Configuration

```yaml
# Enable MQTT protocol support
---
features:
  - mqtt
```

#### `stomp`

Enables the RabbitMQ STOMP plugin for STOMP protocol support.

##### Example Configuration

```yaml
# Enable STOMP protocol support
---
features:
  - stomp
```

### Monitoring

#### `prometheus`

Enables the RabbitMQ Prometheus plugin. The plugin serves metrics over plain HTTP on port 15692 and, while management TLS is on, over HTTPS on port 15691. The `rabbitmq-server` job opens the HTTPS listener itself and presents the management certificate, so a scraper has to trust the management CA (`/mgmt/certs/ca`) and not the RabbitMQ CA. The kit adds no proxy for the TLS port. Under `no-mgmt-tls` the job does not open port 15691 at all, and metrics are available only on port 15692.

##### Example Configuration

```yaml
# Enable Prometheus metrics
---
features:
  - prometheus
```

#### `no-prometheus-tls`

Has no effect. The kit once put a haproxy proxy in front of port 15691 and this feature removed it, but the `rabbitmq-server` job now opens the TLS listener itself whenever management TLS is on and has no property to close it. The feature is still accepted so that existing environment files keep rendering. To serve metrics without TLS, use `no-mgmt-tls`, and note that it also turns off management TLS.

### Stemcell

#### `resolute`

Deploys RabbitMQ on the `ubuntu-resolute` stemcell instead of the default `ubuntu-jammy`. The feature is opt-in, and we recommend setting `stemcell_version` to a resolute version such as `"0.184"` alongside it.

The feature sets the stemcell OS to `ubuntu-resolute` and pins the bpm release to 1.4.41. Releases of bpm older than 1.4.41 do not compile on resolute, and bpm runs on both the `rmq-server` and `haproxy` instance groups, so the pin applies every time the feature is on. The pin lives in `manifests/releases/bpm-resolute.yml` and loads after `manifests/releases/bpm.yml`, so the two files have to be bumped together. The feature also pins the haproxy release to 16.13.0+3.2.25, because the socat bundled in earlier haproxy releases does not compile on resolute and the broker TLS addon runs the haproxy job on the `rmq-broker` instance group. That pin lives in `manifests/releases/haproxy-resolute.yml`, loads after `manifests/releases/haproxy.yml`, and the two haproxy files are bumped together as well.

The kit refuses three situations. It refuses an environment that sets `params.stemcell_os` to anything other than `ubuntu-resolute` while the feature is on, because the feature owns the stemcell OS. It refuses an environment that sets `params.stemcell_os` to `ubuntu-resolute` without the feature, so an environment that relied on that parameter alone needs to enable the feature and drop the parameter. It also refuses `resolute` together with `route-registrar` or `metrics-emitter`, because the routing and metrics emitter releases that those features pin have not been proven on resolute.

The `broker` feature is not yet supported on resolute. The kit does not refuse the combination, but the broker release still calls `chpst`, which resolute does not ship, so the broker job will not start there until we pin a release that no longer needs it.

```yaml
# Deploy on ubuntu-resolute
---
kit:
  features:
    - resolute

params:
  stemcell_version: "0.184"
```

## Feature Compatibility Matrix

| Feature | Compatible With | Conflicts With | Depends On |
|---------|-----------------|----------------|------------|
| `broker` | All except noted conflicts | - | - |
| `no-broker-tls` | Most features | `provided-broker-cert` | `broker` |
| `route-registrar` | Most features | `resolute` | `broker` |
| `nats-tls` | Most features | - | `route-registrar` |
| `no-rmq-tls` | Most features | `provided-rmq-cert` | - |
| `no-mgmt-tls` | Most features | `provided-mgmt-cert` | - |
| `provided-rmq-cert` | Most features | `no-rmq-tls` | - |
| `provided-mgmt-cert` | Most features | `no-mgmt-tls` | - |
| `provided-broker-cert` | Most features | `no-broker-tls` | `broker` |
| `external-rmq-lb` | Most features | - | - |
| `mqtt` | All | - | - |
| `stomp` | All | - | - |
| `prometheus` | All | `no-prometheus-tls` | - |
| `no-prometheus-tls` | All | `prometheus` | - |
| `metrics-emitter` | Most features | `resolute` | `broker` |
| `resolute` | Most features | `route-registrar`, `metrics-emitter` | - |

`broker` is deployable on the 4.x-based release, but it is not yet validated against quorum queues, the RabbitMQ 4.x default queue type. Its default operator policy is off.

## Available Addons

| Addon | Description |
|-------|-------------|
| `register-broker` | Register this broker with the Cloud Foundry in this environment. |
| `deregister-broker` | Deregister this broker from the Cloud Foundry in this environment. |
| `smoke-tests` | Run the smoke test errand for this deployment. This errand will not pass unless you have route registrar enabled. |
| `acceptance-tests` | Run the acceptance test errand for this deployment. Exercises AMQP, management, cluster, HAProxy, and plugin checks against the deployed RabbitMQ cluster. |

### Example Addon Usage

```bash
# Register the broker with CF
genesis do my-env -- register-broker

# Run smoke tests
genesis do my-env -- smoke-tests

# Run acceptance tests
genesis do my-env -- acceptance-tests

# Deregister the broker from CF
genesis do my-env -- deregister-broker
```

## Security Considerations

### TLS Configuration

By default, the RabbitMQ deployment secures all communication with TLS:

- AMQP communication uses port 5671 with TLS
- Management UI uses port 15671 with HTTPS
- If Prometheus is enabled, metrics are exposed over HTTPS on port 15691 with the management certificate

For production deployments, it's recommended to:

1. **Maintain TLS Security**: Avoid using the `no-rmq-tls`, `no-mgmt-tls`, and `no-broker-tls` features in production environments.

2. **Certificate Management**: Consider using the `provided-*-cert` features to supply your own certificates from a trusted certificate authority, especially for external-facing interfaces.

3. **Authentication**: The default broker credentials should be changed. Consider implementing additional authentication methods for production use.

4. **Network Isolation**: Use network segmentation to restrict access to the RabbitMQ cluster, allowing only necessary communication paths.

### User Management

The RabbitMQ deployment creates default users:

- Admin user for management access
- Broker user for service broker access

For production deployments:
1. Rotate credentials regularly
2. Use the principle of least privilege when granting permissions to users
3. Monitor access logs for suspicious activity

## Performance Tuning

### Cluster Sizing

Proper sizing of your RabbitMQ deployment is critical for performance:

1. **Node Count**: Increase `rmq_instances` for higher availability and throughput. For most production workloads, at least 3 nodes are recommended.

2. **VM Sizing**: Adjust `server_vm_type` based on expected workload:
   - Memory is typically the most important resource for RabbitMQ
   - CPU becomes important with many concurrent connections
   - Example sizing:
     - Small workloads: 2 CPU, 4GB RAM
     - Medium workloads: 4 CPU, 8GB RAM 
     - Large workloads: 8+ CPU, 16GB+ RAM

3. **Disk Performance**: Use `server_disk_type` to specify a disk type with:
   - Good throughput for queue operations
   - Low latency for message persistence
   - Sufficient IOPS for high message rates

### Queue Mirroring

**Note**: RabbitMQ 4.x removed classic queue mirroring and uses quorum queues by default.

The broker no longer sets a mirroring policy by default. To have it set an operator policy on the vhosts it creates, set `operator_policy_enabled: true` and give `operator_policy_definition` a JSON definition that RabbitMQ 4.x accepts, such as `{"dead-letter-exchange":"dlx"}`.

### Queue Synchronization During Upgrades

Set `check_queue_sync: true` to ensure queue contents are fully synchronized before node shutdown during upgrades. This prevents potential message loss but may increase upgrade time.

## Upgrading

### General Upgrade Process

1. **Review Release Notes**: Before upgrading, check the release notes for breaking changes or migration requirements.

2. **Backup**: Always take a backup of your RabbitMQ deployment before upgrading:
   ```bash
   # Create a snapshot of your RabbitMQ deployment
   genesis do my-env -- export > rabbitmq-backup.yml
   ```

3. **Incremental Upgrades**: For major version upgrades, consider upgrading incrementally through intermediate versions rather than jumping multiple major versions.

4. **Testing**: Test the upgrade in a non-production environment first.

5. **Perform the Upgrade**:
   ```bash
   genesis deploy my-env
   ```

6. **Verify Functionality**: Run smoke tests after upgrading:
   ```bash
   genesis do my-env -- smoke-tests
   ```

### Version-Specific Considerations

#### Upgrading to RabbitMQ 4.x

This kit deploys RabbitMQ 4.2 (paired with Erlang 27) via the `cf-rabbitmq` release. The same release also supports RabbitMQ 3.13 (paired with Erlang 26). Note the following when upgrading a cluster running an earlier RabbitMQ 3.x release:

- Classic queue mirroring is removed. Quorum queues are the default queue type; migrate any classic mirrored queues to quorum queues before or during the upgrade.
- `check_queue_sync` now waits for quorum queue sync only, not mirrored-queue sync.
- The `broker` feature is not yet validated against RabbitMQ 4.x. The broker's old default `ha-mode` policy targets classic mirrored queues, so the kit turns it off.
- Feature flags gate cluster-wide behavior changes; all nodes must run compatible versions before enabling new feature flags.
- Streams, added in RabbitMQ 3.9, and the feature flags system remain available.

## Troubleshooting

### Common Issues

#### Node Not Joining Cluster

**Symptoms**: Node starts but fails to join the cluster.

**Resolution**:
1. Check network connectivity between nodes
2. Verify Erlang cookie is consistent across nodes
3. Check logs for specific errors:
   ```bash
   genesis do my-env -- logs rabbitmq-server
   ```

#### High Memory Usage

**Symptoms**: RabbitMQ instance using excessive memory, triggering alarms.

**Resolution**:
1. Check for large queues or messages:
   ```bash
   genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_queues name messages memory"
   ```
2. Consider increasing memory limits or implementing a message TTL
3. Review consumer performance if queues are backing up

#### Service Broker Registration Failures

**Symptoms**: The `register-broker` addon fails with authentication or connection errors.

**Resolution**:
1. Verify Cloud Foundry credentials and connectivity
2. Check broker logs:
   ```bash
   genesis do my-env -- logs rabbitmq-broker
   ```
3. Ensure route registration is working if using that feature

### Diagnostic Commands

#### Check Cluster Status

```bash
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl cluster_status"
```

#### List Queues and Their Status

```bash
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_queues name messages consumers memory state"
```

#### Check Broker Status 

```bash
genesis do my-env -- ssh rabbitmq-broker/0 -c "curl -k https://localhost:4566/v2/catalog"
```

#### View Recent Logs

```bash
genesis do my-env -- logs rabbitmq-server --recent
```

## Monitoring and Metrics

### Available Metrics

RabbitMQ exposes a wide range of metrics that can be collected through various means:

1. **Management API**: Basic metrics via HTTP/HTTPS
2. **Prometheus Endpoint**: Comprehensive metrics in Prometheus format
3. **Metrics Emitter**: For Cloud Foundry integration via Loggregator

Key metrics to monitor include:

| Metric Category | Description | Important Metrics |
|----------------|-------------|-------------------|
| Node Health | Overall node status | `rabbitmq_health_checks`, `rabbitmq_node_up` |
| Resource Usage | CPU, memory, disk usage | `rabbitmq_process_resident_memory_bytes`, `rabbitmq_disk_space_available_bytes` |
| Queue Status | Queue depth and performance | `rabbitmq_queue_messages`, `rabbitmq_queue_messages_ready`, `rabbitmq_queue_consumers` |
| Message Rates | Throughput metrics | `rabbitmq_message_published_total`, `rabbitmq_message_delivered_total` |
| Connection Status | Client connection metrics | `rabbitmq_connection_created_total`, `rabbitmq_connection_closed_total` |

### Monitoring Integration

#### Prometheus

When the `prometheus` feature is enabled, metrics are available at:
- `https://<rmq_domain>:15691/metrics` (with TLS, signed by the management CA)
- `http://<rmq_domain>:15692/metrics` (always available, and the only endpoint under `no-mgmt-tls`)

Example Prometheus scrape configuration:

```yaml
scrape_configs:
  - job_name: 'rabbitmq'
    scheme: https
    tls_config:
      insecure_skip_verify: true  # Replace with proper CA configuration in production
    static_configs:
      - targets: ['rabbitmq.example.com:15691']
```

#### Grafana Dashboards

Several Grafana dashboards are available for RabbitMQ Prometheus metrics:
- RabbitMQ-Overview
- RabbitMQ-Queues
- RabbitMQ-Erlang

#### Cloud Foundry Integration

When using the `metrics-emitter` feature, RabbitMQ metrics are sent to the Cloud Foundry Loggregator, making them available through the CF metrics pipeline.

### Alerting Recommendations

Consider setting up alerts for:

1. Node availability issues
2. Queue depth exceeding thresholds
3. High memory or disk usage
4. Message rate anomalies
5. Connection churn

Example alerting rules for Prometheus:

```yaml
groups:
- name: rabbitmq-alerts
  rules:
  - alert: RabbitMQNodeDown
    expr: rabbitmq_node_up == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "RabbitMQ node down"
      description: "RabbitMQ node has been down for more than 5 minutes"
  
  - alert: RabbitMQHighMemoryUsage
    expr: rabbitmq_process_resident_memory_bytes / rabbitmq_resident_memory_limit_bytes > 0.8
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "RabbitMQ high memory usage"
      description: "RabbitMQ memory usage is above 80% for more than 10 minutes"
```