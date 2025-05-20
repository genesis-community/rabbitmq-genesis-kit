# RabbitMQ Genesis Kit Architecture

## System Architecture

The RabbitMQ Genesis Kit deploys a highly available RabbitMQ cluster with optional components depending on your selected features. This document explains the overall architecture and how the components interact.

### Core Components

**RabbitMQ Server Nodes**
- Multiple RabbitMQ server instances forming a cluster
- Data replication between nodes for high availability 
- Each node runs the same RabbitMQ version and plugins
- Erlang cookie shared across nodes for clustering

**HAProxy Layer** (unless using external load balancer)
- Provides load balancing across RabbitMQ nodes
- Handles SSL termination (when configured)
- Exposes standard ports for RabbitMQ protocols
- Single point of entry to the cluster

**Service Broker** (when broker feature is enabled)
- CF RabbitMQ Multitenant Service Broker
- Manages RabbitMQ service instances for CF applications
- Handles service binding and credential management
- Creates isolated vhosts with appropriate permissions

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Client Applications                              │
└───────────────────────────────────┬─────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                                HAProxy                                   │
│           (or External Load Balancer with external-rmq-lb)              │
└───────────┬─────────────────────┬────────────────────────┬──────────────┘
            │                     │                        │
            ▼                     ▼                        ▼
┌───────────────────┐   ┌───────────────────┐   ┌───────────────────┐
│  RabbitMQ Node 1  │   │  RabbitMQ Node 2  │   │  RabbitMQ Node 3  │
├───────────────────┤   ├───────────────────┤   ├───────────────────┤
│ - Message Broker  │   │ - Message Broker  │   │ - Message Broker  │
│ - Management UI   │◄──┼─►Management UI    │◄──┼─►Management UI    │
│ - Plugins         │   │ - Plugins         │   │ - Plugins         │
└─────────┬─────────┘   └─────────┬─────────┘   └─────────┬─────────┘
          │                       │                       │
          └───────────────────────┼───────────────────────┘
                                  │
                    Mirrored Queues / Replicated State
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Service Broker (optional)                           │
├─────────────────────────────────────────────────────────────────────────┤
│ - CF Service Broker API                                                  │
│ - User/Vhost Management                                                  │
│ - Service Plan Implementation                                            │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Cloud Foundry (if used)                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Network Architecture

The RabbitMQ Genesis Kit creates two main networks (which can be the same network):

1. **Server Network** (`server_network` parameter, default: `rabbitmq`)
   - Contains the RabbitMQ server nodes
   - Used for inter-node communication
   - Internal management traffic

2. **Proxy Network** (`proxy_network` parameter, default: `rabbitmq`)
   - Contains the HAProxy instances
   - Exposed to client applications
   - Should be accessible to RabbitMQ users

If the broker feature is enabled, it adds:

3. **Broker Network** (`broker_network` parameter, default: `rabbitmq`)
   - Contains the service broker
   - Must be accessible to Cloud Foundry Cloud Controller
   - Must reach the NATS nodes if route-registrar is used

## Protocol Support

The RabbitMQ Genesis Kit supports multiple messaging protocols:

- **AMQP/AMQPS** - Core protocol (ports 5672/5671)
- **MQTT/MQTTS** - When mqtt feature is enabled (ports 1883/8883)
- **STOMP** - When stomp feature is enabled (ports 61613/61614)
- **Management API** - Administrative interface (ports 15672/15671)
- **Prometheus Metrics** - When prometheus feature is enabled (ports 15692/15691)

## Security Architecture

Security is implemented at multiple levels:

1. **Transport Security**
   - TLS for all protocols by default (can be disabled with no-*-tls features)
   - Certificate management (auto-generated or user-provided)

2. **Authentication**
   - Username/password authentication for messaging protocols
   - Admin user for management interface
   - Broker credentials for Cloud Foundry integration

3. **Authorization**
   - Vhost isolation
   - Permissions model based on RabbitMQ's users, vhosts, and permissions

## Customization Points

The RabbitMQ Genesis Kit provides several ways to customize your deployment:

1. **Features** - Enable or disable components based on requirements
2. **Parameters** - Configure settings through environment variables
3. **VM Types** - Adjust performance characteristics through BOSH VM types
4. **TLS Configuration** - Use provided certificates for custom TLS setup
5. **Cloud Foundry Integration** - Customize service broker behavior

## Genesis Kit Implementation

The kit's implementation is structured as follows:

1. **Hooks** - Perl modules that implement Genesis lifecycle hooks
2. **Manifests** - BOSH deployment manifests and configurations
3. **Addons** - Operational tasks for managing the deployment

The hook system in the kit enables dynamic configuration based on selected features, ensuring that only the necessary components are deployed and properly configured.

## Next Steps

- See [Deployment Guide](../deployment/basic-deployment.md) for how to deploy this architecture
- See [Features](../features/) for details on individual features
- See [Operations](../operations/) for information on managing a deployed cluster