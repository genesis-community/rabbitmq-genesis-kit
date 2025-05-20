# RabbitMQ Service Broker

The RabbitMQ Genesis Kit includes support for deploying the Cloud Foundry RabbitMQ Multitenant Service Broker, which allows Cloud Foundry applications to use RabbitMQ as a managed service.

## Overview

The service broker provides:

1. **Service Instance Management** - Creating and deleting RabbitMQ vhosts (virtual hosts)
2. **Service Binding** - Generating credentials and permissions for applications
3. **Service Plans** - Customizable service tiers with different limits and policies
4. **Integration with Cloud Foundry** - Marketplace listings and instance dashboard

## Architecture

When the `broker` feature is enabled, the Genesis Kit deploys:

1. **Broker VM** - Runs the cf-rabbitmq-multitenant-broker service
2. **Broker Database** - Stores service instance and binding information
3. **Broker API** - HTTPS endpoint that implements the Open Service Broker API
4. **Service Dashboard** - Web UI for managing RabbitMQ service instances

The broker interacts with:
- Cloud Foundry Cloud Controller - For service registration and provisioning requests
- RabbitMQ Management API - To create vhosts, users, and permissions
- Applications - For binding and credential delivery

```
┌────────────────────┐         ┌────────────────────┐
│  Cloud Foundry     │         │   RabbitMQ Cluster │
│  ┌──────────────┐  │         │  ┌──────────────┐  │
│  │Cloud         │  │         │  │  RabbitMQ    │  │
│  │Controller    │◄─┼─────────┼─►│  Management  │  │
│  └──────────────┘  │         │  │  API         │  │
│         ▲          │         │  └──────────────┘  │
└─────────┼──────────┘         └────────────────────┘
          │                                ▲
          │                                │
          ▼                                │
┌────────────────────┐                     │
│   Service Broker   │                     │
│  ┌──────────────┐  │                     │
│  │ CF RabbitMQ  │  │                     │
│  │ Multitenant  ├──┼─────────────────────┘
│  │ Broker       │  │
│  └──────────────┘  │
│         ▲          │
└─────────┼──────────┘
          │
          ▼
┌────────────────────┐
│   CF Application   │
│  ┌──────────────┐  │
│  │ Application  │  │
│  │ Using AMQP   │  │
│  │ Client       │  │
│  └──────────────┘  │
└────────────────────┘
```

## Enabling the Broker

To enable the broker, add the `broker` feature to your environment:

```yaml
# In your environment file (e.g., cf-rabbitmq.yml)
kit:
  features:
    - broker
```

### Required Parameters

The broker feature requires the following parameters:

```yaml
params:
  # Required broker parameter
  broker_domain: rabbitmq-broker.example.com
```

### Optional Parameters

Customize the broker with these parameters:

```yaml
params:
  # Optional broker parameters with defaults shown
  broker_username: broker
  broker_network: rabbitmq
  broker_vm_type: small
  broker_name: p-rabbitmq
  service_name: p-rabbitmq
  ha_sync_mode: manual
```

## Registering the Broker with Cloud Foundry

After deployment, register the broker with Cloud Foundry using the provided addon:

```bash
# Register the broker
genesis do my-env -- register-broker
```

This command:
1. Authenticates with Cloud Foundry
2. Registers the broker using the configured parameters
3. Makes service plans available in the marketplace

## Using the Service

Applications can use the service through the standard CF service workflows:

```bash
# View service in marketplace
cf marketplace

# Create a service instance
cf create-service p-rabbitmq standard my-rabbit

# Bind to an application
cf bind-service my-app my-rabbit

# Check environment for credentials
cf env my-app
```

## Service Plans

The broker provides service plans that define resource limits and policies. The default plans include:

1. **standard** - Basic plan with default settings
   - Single vhost
   - Default user permissions
   - No specific resource limits

2. **ha** - High availability plan
   - Single vhost with HA enabled
   - Mirrored queues across all nodes
   - Default user permissions

## TLS Configuration

By default, the broker serves HTTPS on port 4566. To disable TLS for the broker, add the `no-broker-tls` feature:

```yaml
kit:
  features:
    - broker
    - no-broker-tls
```

**Warning:** This is not recommended for production deployments.

## Custom Certificates

To use custom certificates for the broker, add the `provided-broker-cert` feature:

```yaml
kit:
  features:
    - broker
    - provided-broker-cert
```

Then, provide your certificates in Vault:

```bash
# Store custom broker certificate and key
safe set secret/my-env/rabbitmq/broker/certs/server certificate@cert.pem key@key.pem
```

## Route Registration

To expose the broker through Cloud Foundry's routing tier, add the `route-registrar` feature:

```yaml
kit:
  features:
    - broker
    - route-registrar
```

This registers routes with the CF GoRouter, making the broker and management UI accessible through CF domains.

## Metrics Emission

To enable metrics from RabbitMQ to be sent to Cloud Foundry's Loggregator, add the `metrics-emitter` feature:

```yaml
kit:
  features:
    - broker
    - metrics-emitter
```

## Troubleshooting

### Common Issues

1. **Broker Registration Fails**
   - Check connectivity between broker and CF API
   - Verify CF credentials and permissions
   - Check broker logs: `genesis do my-env -- logs rabbitmq-broker`

2. **Service Creation Fails**
   - Check broker logs for errors
   - Verify connectivity to RabbitMQ management API
   - Check RabbitMQ has capacity for new vhosts

3. **Service Binding Fails**
   - Check broker logs for errors
   - Verify RabbitMQ user creation permissions
   - Check that the vhost exists and is healthy

### Diagnostic Commands

```bash
# Check broker status
genesis do my-env -- ssh rabbitmq-broker/0 -c "monit summary"

# Test broker API locally
genesis do my-env -- ssh rabbitmq-broker/0 -c "curl -k https://localhost:4566/v2/catalog -u broker:password"

# Check broker logs
genesis do my-env -- logs rabbitmq-broker

# Test connection to RabbitMQ
genesis do my-env -- ssh rabbitmq-broker/0 -c "curl -k https://rabbitmq.example.com:15671/api/overview -u admin:password"
```

## Advanced Configuration

### Custom Service Plans

To customize service plans:

1. SSH into the broker VM
2. Edit the service configuration files
3. Restart the broker services

```bash
# SSH to broker
genesis do my-env -- ssh rabbitmq-broker/0

# Edit config
sudo vim /var/vcap/jobs/rabbitmq-broker/config/service_catalog.yml

# Restart broker
sudo monit restart rabbitmq-broker
```

### High Availability Settings

The `ha_sync_mode` parameter controls how queues are synchronized between nodes:

```yaml
params:
  ha_sync_mode: automatic  # Instead of the default 'manual'
```

Settings:
- `manual` - Queues must be manually synchronized (default, safer for performance)
- `automatic` - Queues synchronize automatically when new mirrors are added (safer for data integrity)