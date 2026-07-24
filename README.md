# RabbitMQ Genesis Kit

## Overview

The **RabbitMQ Genesis Kit** deploys a production-ready RabbitMQ message broker cluster and, optionally, the Cloud Foundry RabbitMQ Multitenant Service Broker. This kit provides a complete messaging solution that can be used standalone or integrated with Cloud Foundry.

### Architecture

At its core, this kit deploys:
- A customizable RabbitMQ cluster with configurable node count
- HAProxy for load balancing (optional)
- TLS encryption for all communications (configurable)
- Service broker integration with Cloud Foundry (optional)
- Monitoring and metrics capabilities

## Key Features

- **Highly Available Clustering** - Deploy 3+ node RabbitMQ clusters for high availability
- **Security** - TLS encryption for all messaging protocols and management interfaces
- **Cloud Foundry Integration** - Service broker for easy application binding
- **Protocol Support** - Core AMQP with optional MQTT and STOMP protocols
- **Monitoring** - Prometheus integration and metrics emission to CF Loggregator
- **Flexible Networking** - Support for both internal HAProxy and external load balancers
- **Easy Administration** - Management UI with secured access

## Requirements

- BOSH Director with adequate resources
- Genesis v2 or higher
- Network connectivity for client applications
- (Optional) Cloud Foundry deployment for broker integration
- (Optional) Load balancer for external-lb configuration

## Quick Start

To use this kit, you don't even need to clone the repository:

```bash
# Create a rabbitmq-deployments repo using the latest version of the kit
genesis init --kit rabbitmq

# Create a new environment
cd rabbitmq-deployments
genesis new my-rabbitmq

# Edit the environment files as needed
vi my-rabbitmq/my-rabbitmq.yml

# Deploy
genesis deploy my-rabbitmq
```

### Complete Example

To deploy a 3-node RabbitMQ cluster with CF broker integration:

```bash
# 1. Create a deployment repository
genesis init --kit rabbitmq -d my-rabbitmq-configs

# 2. Create a new environment
cd my-rabbitmq-configs
genesis new prod-rabbitmq

# 3. Configure your environment in prod-rabbitmq/prod-rabbitmq.yml
#    Example content:
#    ---
#    kit:
#      name:    rabbitmq
#      version: latest
#    
#    params:
#      env: prod-rabbitmq
#      rmq_domain: rabbitmq.example.com
#      rmq_instances: 3
#      availability_zones: [z1, z2, z3]
#    
#    features:
#      - broker
#      - route-registrar
#      - prometheus

# 4. Deploy!
genesis deploy prod-rabbitmq
```

## Common Maintenance Operations

- **Register Broker with CF**: `genesis do prod-rabbitmq register-broker`
- **Run Smoke Tests**: `genesis do prod-rabbitmq smoke-tests`
- **Run Acceptance Tests**: `genesis do prod-rabbitmq acceptance-tests`
- **Deregister Broker**: `genesis do prod-rabbitmq deregister-broker`

## Configuration Options

For a complete list of all configuration options, features, and maintenance operations, please refer to the [MANUAL.md](MANUAL.md) file.

## License

The RabbitMQ Genesis Kit is released under the MIT License.