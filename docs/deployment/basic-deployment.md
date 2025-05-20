# Basic RabbitMQ Deployment Guide

This guide walks through deploying a simple RabbitMQ cluster using the Genesis Kit. We'll cover the prerequisites, configuration, deployment, and validation steps.

## Prerequisites

Before deploying RabbitMQ, ensure you have:

1. **Genesis CLI** (v2.7.9 or higher)
2. **BOSH Director** with adequate resources
3. **Cloud Config** with appropriate networks and VM types
4. **Genesis Vault** for credentials management

## Step 1: Initialize Your Deployment Repository

First, create a new deployment repository using the Genesis CLI:

```bash
# Create a new directory for your RabbitMQ deployments
mkdir -p ~/deployments
cd ~/deployments

# Initialize the repository with the RabbitMQ Genesis Kit
genesis init --kit rabbitmq

# This creates a 'rabbitmq-deployments' directory
cd rabbitmq-deployments
```

## Step 2: Create a New Environment

Next, create a new environment for your RabbitMQ deployment:

```bash
# Create a new environment (e.g., 'sandbox')
genesis new sandbox
```

This will prompt you for some basic information:
- Whether to deploy the service broker (typically 'no' for a basic deployment)
- The domain for your RabbitMQ cluster

After answering these questions, Genesis will create initial deployment files in the `sandbox` directory.

## Step 3: Configure Your Environment

Edit the environment file (`sandbox/sandbox.yml`) to configure your deployment:

```yaml
---
kit:
  name: rabbitmq
  version: latest
  features:
    - (( replace ))
    # Add any features you want (e.g., prometheus, mqtt)
    - prometheus

genesis:
  env: sandbox
  vault: secret/sandbox/rabbitmq

params:
  # Basic parameters
  rmq_domain: rabbitmq.example.com
  rmq_instances: 3
  availability_zones: [z1, z2, z3]
  server_network: rabbitmq
  proxy_network: rabbitmq
  
  # Resources
  server_vm_type: medium
  proxy_vm_type: small
  server_disk_type: persistent
```

## Step 4: Configure Cloud Config

Ensure your BOSH cloud config includes the necessary networks and VM types:

```yaml
# Example network configuration (should be in your cloud config)
networks:
- name: rabbitmq
  subnets:
  - range: 10.0.0.0/24
    gateway: 10.0.0.1
    static: [10.0.0.10-10.0.0.50]
    reserved: [10.0.0.1-10.0.0.9]
    dns: [8.8.8.8, 8.8.4.4]
    cloud_properties:
      name: my-network

# Example VM types
vm_types:
- name: small
  cloud_properties:
    instance_type: t3.small
- name: medium
  cloud_properties:
    instance_type: t3.medium
```

## Step 5: Deploy RabbitMQ

Now deploy RabbitMQ:

```bash
# Check that your configuration is valid
genesis manifest sandbox

# Deploy RabbitMQ
genesis deploy sandbox
```

This will:
1. Generate a BOSH manifest
2. Create and store necessary credentials in Vault
3. Upload any required releases to your BOSH director
4. Deploy the RabbitMQ cluster

## Step 6: Verify Your Deployment

After deployment completes, verify that everything is working properly:

```bash
# Get information about your deployment
genesis info sandbox

# Check the status of the deployment
bosh -d sandbox-rabbitmq instances

# SSH to a node to check cluster status
genesis do sandbox -- ssh rabbitmq/0 -c "rabbitmqctl cluster_status"
```

## Step 7: Access RabbitMQ

You can access RabbitMQ in different ways:

### Management UI

Access the Management UI at `https://<rmq_domain>:15671`
- Username and password will be shown in the `genesis info sandbox` output

### AMQP Connection

Connect to RabbitMQ over AMQP:
- Host: `<rmq_domain>`
- Port: 5671 (TLS) or 5672 (non-TLS if `no-rmq-tls` feature is enabled)
- Username/password: Check the admin credentials from `genesis info sandbox`

## Common Issues and Troubleshooting

### Deployment Fails

If your deployment fails, check:
1. BOSH logs: `bosh -d sandbox-rabbitmq logs`
2. Cloud config alignment with your params: Make sure the networks, VM types, and availability zones exist
3. Genesis errors: Look for errors in the Genesis output

### RabbitMQ Nodes Don't Cluster

If nodes don't join the cluster:
1. Check they can communicate on the server network
2. Verify the Erlang cookie is consistent across nodes
3. Check node logs: `genesis do sandbox -- logs rabbitmq-server`

### Management UI Not Accessible

If you can't access the Management UI:
1. Verify the domain resolves to your HAProxy IP
2. Check HAProxy logs: `genesis do sandbox -- logs rabbitmq-haproxy`
3. Ensure port 15671 is accessible from your client

## Next Steps

- [Deploying with Service Broker](broker-deployment.md)
- [Configuring External Load Balancers](external-lb.md)
- [Adding Prometheus Monitoring](../integration/prometheus.md)
- [Basic Operations](../operations/basic-operations.md)