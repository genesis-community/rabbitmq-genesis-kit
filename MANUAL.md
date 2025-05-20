# RabbitMQ Genesis Kit Manual

The **RabbitMQ Genesis Kit** deploys a RabbitMQ cluster and, optionally, the CF RabbitMQ Multitenant Service Broker.

## Table of Contents

- [Overview](#overview)
- [Deployment Architecture](#deployment-architecture)
- [Base Parameters](#base-parameters)
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
- [Feature Compatibility Matrix](#feature-compatibility-matrix)
- [Available Addons](#available-addons)
- [Security Considerations](#security-considerations)
- [Performance Tuning](#performance-tuning)
- [Upgrading](#upgrading)
- [Troubleshooting](#troubleshooting)
- [Monitoring and Metrics](#monitoring-and-metrics)

## Overview

The RabbitMQ Genesis Kit provides a production-ready RabbitMQ cluster deployment with optional integration to Cloud Foundry. It leverages the power of BOSH to manage the lifecycle of the RabbitMQ service, including deployment, updates, and recovery from failure scenarios.

## Deployment Architecture

The standard RabbitMQ deployment architecture consists of:

1. **RabbitMQ Server Nodes**: Multiple RabbitMQ server instances forming a cluster for high availability.
2. **HAProxy Layer**: A proxying layer to provide load balancing across the cluster nodes (unless using external load balancing).
3. **Service Broker** (optional): When integrating with Cloud Foundry, a service broker that manages RabbitMQ service instances.

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
                    Mirrored Queues
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
| `proxy_vm_type` | The VM type for the HAProxy VM. | `small` |
| `server_disk_type` | The disk type for RabbitMQ server nodes. Used for cluster configuration, queue config, and durable queue data. | `rabbitmq` |
| `stemcell_os` | The OS of the stemcell to use. | `ubuntu-jammy` |
| `stemcell_version` | The version of the stemcell to use. | `latest` |
| `check_queue_sync` | If true, pre-stop script will wait until mirrored and quorum queues are synced before shutting down. | `false` |

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

##### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `broker_domain` | **REQUIRED** - The domain for the RabbitMQ CF Broker. Used to populate SANs on the certificate. | *(No default)* |
| `broker_username` | The username that the service broker will accept for authentication. | `broker` |
| `broker_network` | The network for the RabbitMQ Multitenant Broker. Must be reachable by CF Cloud Controller or GoRouters if using route-registrar. | `rabbitmq` |
| `broker_vm_type` | The VM type for the broker VM. | `small` |
| `broker_name` | The name of the broker as registered with Cloud Foundry. | `p-rabbitmq` |
| `service_name` | The name of the service exposed in the CF marketplace. | `p-rabbitmq` |
| `ha_sync_mode` | The ha-sync-mode for vhosts created by this broker. | `manual` |

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
  ha_sync_mode: automatic
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

#### `no-mgmt-tls`

Disables the TLS listener for the Management API on port 15671, and will instead listen for plaintext HTTP traffic on port 15672.

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

#### `provided-broker-cert`

Requires you to provide your own certificates for the Service Broker instead of generating them. You must populate:

* `secret/<your/env>/rabbitmq/broker/certs/server:certificate`
* `secret/<your/env>/rabbitmq/broker/certs/server:key`

### Load Balancing

#### `external-rmq-lb`

Removes the HAProxy VM and exposes the RabbitMQ nodes directly through a load balancer using a vm_extension defined in your cloud config.

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

Enables the RabbitMQ Prometheus plugin and metrics scraping endpoint on port 15691. This TLS endpoint serves the same certificate as the RabbitMQ cluster.

##### Example Configuration

```yaml
# Enable Prometheus metrics
---
features:
  - prometheus
```

#### `no-prometheus-tls`

Disables the TLS frontend at port 15691, and leaves the non-TLS Prometheus listener at port 15692.

## Feature Compatibility Matrix

| Feature | Compatible With | Conflicts With | Depends On |
|---------|-----------------|----------------|------------|
| `broker` | All except noted conflicts | - | - |
| `no-broker-tls` | Most features | `provided-broker-cert` | `broker` |
| `route-registrar` | Most features | - | `broker` |
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
| `metrics-emitter` | Most features | - | `broker` |

## Available Addons

| Addon | Description |
|-------|-------------|
| `register-broker` | Register this broker with the Cloud Foundry in this environment. |
| `deregister-broker` | Deregister this broker from the Cloud Foundry in this environment. |
| `smoketest` | Run the smoke test errand for this deployment. This errand will not pass unless you have route registrar enabled. |

### Example Addon Usage

```bash
# Register the broker with CF
genesis do my-env -- register-broker

# Run smoke tests
genesis do my-env -- smoketest

# Deregister the broker from CF
genesis do my-env -- deregister-broker
```

## Security Considerations

### TLS Configuration

By default, the RabbitMQ deployment secures all communication with TLS:

- AMQP communication uses port 5671 with TLS
- Management UI uses port 15671 with HTTPS
- If Prometheus is enabled, metrics are exposed over HTTPS on port 15691

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

When using the broker, the `ha_sync_mode` parameter controls queue mirroring behavior:

- `manual`: Queues must be manually synchronized (default)
- `automatic`: Queues synchronize automatically when new mirrors are added

For production workloads with critical data, consider setting `ha_sync_mode: automatic`.

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
   genesis do my-env -- smoketest
   ```

### Version-Specific Considerations

#### Upgrading to RabbitMQ 3.8+

- Quorum queues are available as an alternative to mirrored queues
- Management UI has significant changes
- New Prometheus metrics format

#### Upgrading to RabbitMQ 3.9+

- Support for Streams
- Feature flags system for controlling new features
- Improved observability

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
- `https://<rmq_domain>:15691/metrics` (with TLS)
- `http://<rmq_domain>:15692/metrics` (without TLS, when `no-prometheus-tls` is enabled)

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