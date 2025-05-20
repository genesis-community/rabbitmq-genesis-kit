# Basic RabbitMQ Operations Guide

This guide covers common operational tasks for managing your RabbitMQ deployment created with the Genesis Kit.

## Viewing Deployment Information

Get an overview of your RabbitMQ deployment's connection details:

```bash
# Display connection information and credentials
genesis info my-env
```

This shows:
- RabbitMQ Management UI URL, username, and password
- Service Broker URL and credentials (if broker is enabled)
- Broker and Service names (if broker is enabled)

## Checking Deployment Status

View the status of your deployment:

```bash
# List all VMs in the deployment
bosh -d my-env-rabbitmq instances

# Check VM health
bosh -d my-env-rabbitmq instances --ps

# View recent task logs
bosh -d my-env-rabbitmq tasks --recent=5
```

## Accessing RabbitMQ Nodes

SSH into RabbitMQ nodes:

```bash
# SSH to the first RabbitMQ node
genesis do my-env -- ssh rabbitmq/0

# SSH to the HAProxy node
genesis do my-env -- ssh rabbitmq-haproxy/0

# SSH to the broker node (if broker feature is enabled)
genesis do my-env -- ssh rabbitmq-broker/0
```

## Viewing Logs

Access logs from different components:

```bash
# View recent RabbitMQ server logs
genesis do my-env -- logs rabbitmq-server --recent

# View recent HAProxy logs
genesis do my-env -- logs rabbitmq-haproxy --recent

# View recent broker logs (if broker feature is enabled)
genesis do my-env -- logs rabbitmq-broker --recent

# Follow logs in real-time
genesis do my-env -- logs rabbitmq-server --follow

# View logs for a specific instance
genesis do my-env -- logs rabbitmq-server/0
```

## RabbitMQ Cluster Management

### Checking Cluster Status

```bash
# Check cluster status
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl cluster_status"

# List queues and their status
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_queues name messages consumers memory state"

# List exchanges
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_exchanges name type durable"

# List connections
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_connections user peer_host state channels"
```

### Node Management

```bash
# Stop the RabbitMQ application on a node (leaves Erlang VM running)
genesis do my-env -- ssh rabbitmq/1 -c "rabbitmqctl stop_app"

# Start the RabbitMQ application on a node
genesis do my-env -- ssh rabbitmq/1 -c "rabbitmqctl start_app"

# Reset a node (removes all data! use with caution)
genesis do my-env -- ssh rabbitmq/1 -c "rabbitmqctl reset"

# Restart a node
genesis do my-env -- ssh rabbitmq/1 -c "monit restart rabbitmq-server"
```

### Queue Management

```bash
# List all queues with detailed information
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_queues name messages consumers memory state slave_pids synchronised_slave_pids"

# Purge a queue (remove all messages)
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl purge_queue <queue_name> -p <vhost>"

# Delete a queue
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl delete_queue <queue_name> -p <vhost>"

# Sync a mirrored queue manually
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl sync_queue <queue_name> -p <vhost>"
```

### User Management

```bash
# List all users
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_users"

# Add a new user
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl add_user <username> <password>"

# Set user permissions
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl set_permissions -p <vhost> <username> '.*' '.*' '.*'"

# Set user tags (roles)
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl set_user_tags <username> administrator"

# Delete a user
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl delete_user <username>"

# Change a user's password
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl change_password <username> <new_password>"
```

## Service Broker Management

If you've deployed with the `broker` feature, you can manage the broker:

```bash
# Register the broker with Cloud Foundry
genesis do my-env -- register-broker

# Deregister the broker from Cloud Foundry
genesis do my-env -- deregister-broker

# Run smoke tests
genesis do my-env -- smoketest
```

## Common Maintenance Tasks

### Rotating Credentials

To rotate credentials for the RabbitMQ admin user:

1. Generate a new password:
   ```bash
   NEW_PASSWORD=$(openssl rand -base64 24)
   echo $NEW_PASSWORD
   ```

2. Update the password in RabbitMQ:
   ```bash
   genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl change_password admin '$NEW_PASSWORD'"
   ```

3. Update the password in Vault:
   ```bash
   safe set secret/my-env/rabbitmq/rabbitmq/admin/management password="$NEW_PASSWORD"
   ```

### Enabling a Plugin

To enable a RabbitMQ plugin:

```bash
# Check available plugins
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmq-plugins list"

# Enable a plugin (on all nodes)
for i in {0..2}; do
  genesis do my-env -- ssh rabbitmq/$i -c "rabbitmq-plugins enable <plugin_name>"
done
```

Note: For persistent plugin enablement, you should modify your environment's features and redeploy.

### Policy Management

Create or update policies:

```bash
# Create a policy for HA queues
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl set_policy ha-all --apply-to queues '.*' '{\"ha-mode\":\"all\",\"ha-sync-mode\":\"automatic\"}' -p <vhost>"

# List all policies
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_policies"

# Delete a policy
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl clear_policy <policy_name> -p <vhost>"
```

## Scaling Operations

### Adding Capacity

To increase RabbitMQ node count:

1. Update your environment file:
   ```yaml
   params:
     rmq_instances: 5  # Increase from default of 3
   ```

2. Redeploy:
   ```bash
   genesis deploy my-env
   ```

### Scaling VM Resources

To change VM types for better performance:

1. Update your environment file:
   ```yaml
   params:
     server_vm_type: large      # More resources for RabbitMQ nodes
     proxy_vm_type: medium      # More resources for HAProxy
     server_disk_type: large    # More storage for message persistence
   ```

2. Redeploy:
   ```bash
   genesis deploy my-env
   ```

## Upgrades

### Upgrading the Genesis Kit

To upgrade to a newer version of the Genesis Kit:

1. Update your environment file to specify the new kit version:
   ```yaml
   kit:
     name: rabbitmq
     version: X.Y.Z  # Replace with the desired version
   ```

2. Deploy the update:
   ```bash
   genesis deploy my-env
   ```

### BOSH Stemcell Updates

To update the stemcell:

1. Update your environment file:
   ```yaml
   params:
     stemcell_version: X.Y  # Replace with the desired version
   ```

2. Deploy the update:
   ```bash
   genesis deploy my-env
   ```

## Monitoring Tasks

### Health Checks

```bash
# Check overall health
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmq-diagnostics check_running"

# Check if all nodes are running
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmq-diagnostics check_cluster_status"

# Check alarms
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmq-diagnostics alarms"

# Check virtual hosts
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmq-diagnostics check_virtual_hosts"
```

### Resource Monitoring

```bash
# Check memory status
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl status | grep -A 10 'Memory'"

# Check file descriptors
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl status | grep -A 5 'File Descriptors'"

# Check disk space
genesis do my-env -- ssh rabbitmq/0 -c "df -h /var/vcap/store"
```

### Performance Monitoring

```bash
# Check message rates
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_queues name messages message_stats.publish_details.rate message_stats.deliver_details.rate"

# Check connection count
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_connections | wc -l"

# Check channel count
genesis do my-env -- ssh rabbitmq/0 -c "rabbitmqctl list_channels | wc -l"
```

## Backup and Restore

### Backing Up RabbitMQ Definitions

```bash
# Export definitions through the Management API
genesis do my-env -- ssh rabbitmq/0 -c "curl -s -u admin:<password> -H 'Content-Type: application/json' -X GET http://localhost:15672/api/definitions > /tmp/rabbitmq-definitions.json"

# Download the definitions file
genesis do my-env -- ssh rabbitmq/0 -c "cat /tmp/rabbitmq-definitions.json" > rabbitmq-definitions.json
```

### Restoring Definitions

```bash
# Upload definitions file
genesis do my-env -- ssh rabbitmq/0 -c "cat > /tmp/rabbitmq-definitions.json" < rabbitmq-definitions.json

# Import definitions through the Management API
genesis do my-env -- ssh rabbitmq/0 -c "curl -s -u admin:<password> -H 'Content-Type: application/json' -X POST -d @/tmp/rabbitmq-definitions.json http://localhost:15672/api/definitions"
```

Note: This approach primarily backs up metadata (users, queues, exchanges, bindings) but not the messages themselves.

## Troubleshooting

For detailed troubleshooting guidance, see the [Common Issues](../troubleshooting/common-issues.md) document.

## Next Steps

- [Advanced Operations](advanced-operations.md)
- [Monitoring and Metrics](../monitoring/overview.md)
- [Performance Tuning](performance-tuning.md)
- [Security Hardening](security-hardening.md)