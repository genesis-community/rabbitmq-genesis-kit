# Troubleshooting Common RabbitMQ Issues

This guide covers common issues you might encounter with your RabbitMQ Genesis Kit deployment and how to troubleshoot them.

## Deployment Issues

### Genesis Deploy Fails During Manifest Generation

**Symptoms**: 
- Genesis reports errors during the manifest generation phase
- Deployment doesn't reach BOSH

**Possible Causes**:
1. Missing required parameters
2. Feature conflicts
3. Genesis Vault access issues
4. Cloud config inconsistencies

**Troubleshooting Steps**:

1. **Check for parameter errors**:
   ```bash
   # Validate your environment against the kit's requirements
   genesis check <env>
   ```

2. **Check feature compatibility**:
   - Review the [Feature Compatibility Matrix](../../MANUAL.md#feature-compatibility-matrix)
   - Ensure you're not using conflicting features (e.g., `no-rmq-tls` and `provided-rmq-cert`)

3. **Validate Vault access**:
   ```bash
   # Test Vault connectivity
   safe get secret/handshake
   
   # Check path to credentials
   safe get secret/<your-env>/rabbitmq/rabbitmq/admin/broker
   ```

4. **Check Genesis version compatibility**:
   ```bash
   # Verify your Genesis version is compatible with the kit
   genesis -v
   ```

### BOSH Deployment Fails

**Symptoms**:
- Genesis successfully creates the manifest but BOSH deployment fails
- Error messages in BOSH deploy output

**Possible Causes**:
1. Network configuration issues
2. Resource constraints
3. VM provisioning failures
4. Release version issues

**Troubleshooting Steps**:

1. **Check BOSH task logs**:
   ```bash
   # Find the failed task
   bosh tasks --recent=5
   
   # Get detailed logs for the failed task
   bosh task <task-id> --debug
   ```

2. **Verify cloud config**:
   ```bash
   # Check networks, VM types, disk types, and availability zones
   bosh cloud-config
   
   # Verify they match what's in your deployment
   genesis manifest <env> | grep -E 'networks:|vm_type:|disk_type:|azs:'
   ```

3. **Check infrastructure capacity**:
   - Ensure your IaaS has enough resources (CPU, memory, IPs, etc.)
   - Verify VM quotas and service limits

4. **Check release compatibility**:
   ```bash
   # List uploaded releases
   bosh releases
   
   # Check if required releases exist and versions match
   ```

## Runtime Issues

### RabbitMQ Nodes Fail to Cluster

**Symptoms**:
- Some nodes start in standalone mode
- Nodes don't join the cluster
- `rabbitmqctl cluster_status` shows missing nodes

**Possible Causes**:
1. Network connectivity issues between nodes
2. Erlang cookie mismatch
3. Node name resolution problems
4. Different RabbitMQ versions

**Troubleshooting Steps**:

1. **Check cluster status on each node**:
   ```bash
   # SSH to each node and check status
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl cluster_status"
   genesis do <env> -- ssh rabbitmq/1 -c "rabbitmqctl cluster_status"
   ```

2. **Verify Erlang cookie consistency**:
   ```bash
   # Check cookie on each node
   genesis do <env> -- ssh rabbitmq/0 -c "cat /var/vcap/store/rabbitmq/.erlang.cookie"
   genesis do <env> -- ssh rabbitmq/1 -c "cat /var/vcap/store/rabbitmq/.erlang.cookie"
   ```

3. **Test network connectivity**:
   ```bash
   # Test network between nodes
   genesis do <env> -- ssh rabbitmq/0 -c "ping -c 3 <rabbitmq/1-ip>"
   ```

4. **Check logs for clustering errors**:
   ```bash
   # View RabbitMQ logs
   genesis do <env> -- logs rabbitmq-server/0 --recent
   ```

5. **Restart clustering process**:
   ```bash
   # Reset problematic nodes and rejoin
   genesis do <env> -- ssh rabbitmq/1 -c "rabbitmqctl stop_app"
   genesis do <env> -- ssh rabbitmq/1 -c "rabbitmqctl reset"
   genesis do <env> -- ssh rabbitmq/1 -c "rabbitmqctl join_cluster rabbit@<node0-hostname>"
   genesis do <env> -- ssh rabbitmq/1 -c "rabbitmqctl start_app"
   ```

### High Memory Usage and Memory Alarms

**Symptoms**:
- RabbitMQ memory alarms triggered
- Publishers blocked
- Messages in `/var/log/rabbitmq/rabbit@<hostname>.log` about memory pressure

**Possible Causes**:
1. Too many queued messages
2. Too many connections
3. Insufficient memory allocation
4. Memory leaks in plugins

**Troubleshooting Steps**:

1. **Check memory alarm status**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl status | grep -A 5 memory"
   ```

2. **Identify memory-intensive queues**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl list_queues name messages memory consumers"
   ```

3. **Check connection count**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl list_connections | wc -l"
   ```

4. **Review memory watermark settings**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl environment | grep vm_memory"
   ```

5. **Mitigations**:
   - Delete unused queues
   - Implement message TTL for queues
   - Close idle connections
   - Increase VM memory (adjust `server_vm_type` to a larger size)

### Service Broker Issues

**Symptoms**:
- `register-broker` addon fails
- CF marketplace doesn't show RabbitMQ service
- Service instance creation fails
- Binding services fails

**Possible Causes**:
1. Broker connectivity issues with Cloud Foundry
2. Authentication failures
3. TLS/certificate problems
4. Broker connectivity issues with RabbitMQ

**Troubleshooting Steps**:

1. **Check broker status**:
   ```bash
   genesis do <env> -- ssh rabbitmq-broker/0 -c "monit summary"
   ```

2. **Verify broker logs**:
   ```bash
   genesis do <env> -- logs rabbitmq-broker --recent
   ```

3. **Test broker API**:
   ```bash
   # Get broker URL and credentials from Genesis info
   genesis info <env>
   
   # Test catalog endpoint
   genesis do <env> -- ssh rabbitmq-broker/0 -c "curl -s -k https://localhost:4566/v2/catalog -u <broker_username>:<broker_password> | jq"
   ```

4. **Check Cloud Foundry connectivity**:
   ```bash
   # Test connection to CF API
   genesis do <env> -- ssh rabbitmq-broker/0 -c "curl -k <cf_api_url>/v2/info"
   ```

5. **Verify broker registration**:
   ```bash
   # On a CF admin client
   cf service-brokers | grep rabbitmq
   ```

### HAProxy Issues

**Symptoms**:
- Cannot connect to RabbitMQ via the HAProxy frontend
- Management UI inaccessible
- Connection refused errors

**Possible Causes**:
1. HAProxy configuration issues
2. Certificate problems for TLS endpoints
3. Backend RabbitMQ node issues
4. Network routing problems

**Troubleshooting Steps**:

1. **Check HAProxy status**:
   ```bash
   genesis do <env> -- ssh rabbitmq-haproxy/0 -c "monit summary"
   ```

2. **Verify HAProxy logs**:
   ```bash
   genesis do <env> -- logs rabbitmq-haproxy --recent
   ```

3. **Test network connectivity**:
   ```bash
   # Test frontend ports
   genesis do <env> -- ssh rabbitmq-haproxy/0 -c "netstat -tulpn | grep haproxy"
   
   # Test backend connectivity
   genesis do <env> -- ssh rabbitmq-haproxy/0 -c "ping -c 3 <rabbitmq-node-ip>"
   ```

4. **Check TLS certificates**:
   ```bash
   # Verify certificate expiration
   genesis do <env> -- ssh rabbitmq-haproxy/0 -c "openssl x509 -in /var/vcap/jobs/haproxy/config/ssl/cert.pem -text -noout | grep -A 2 'Validity'"
   ```

## Management UI Issues

### Cannot Access Management UI

**Symptoms**:
- Unable to reach the Management UI at `https://<rmq_domain>:15671`
- Browser shows connection errors

**Possible Causes**:
1. DNS resolution issues
2. TLS certificate problems
3. HAProxy configuration issues
4. Management plugin not enabled

**Troubleshooting Steps**:

1. **Verify DNS resolution**:
   ```bash
   # Test DNS resolution
   nslookup <rmq_domain>
   ```

2. **Check TLS certificate validity**:
   ```bash
   # Test SSL connection
   openssl s_client -connect <rmq_domain>:15671
   ```

3. **Verify management plugin is enabled**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmq-plugins list | grep management"
   ```

4. **Test local connectivity to the Management UI**:
   ```bash
   # Test from HAProxy
   genesis do <env> -- ssh rabbitmq-haproxy/0 -c "curl -k https://localhost:15671/"
   
   # Test from RabbitMQ node
   genesis do <env> -- ssh rabbitmq/0 -c "curl -k https://localhost:15671/"
   ```

### Authentication Failures in Management UI

**Symptoms**:
- Unable to log in to Management UI
- "Invalid credentials" errors

**Possible Causes**:
1. Incorrect username/password
2. User permissions issues
3. User not created properly

**Troubleshooting Steps**:

1. **Verify admin credentials**:
   ```bash
   # Get the admin password from Genesis
   genesis info <env>
   ```

2. **Check users on RabbitMQ**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl list_users"
   ```

3. **Reset admin password if needed**:
   ```bash
   # Generate a new password
   NEW_PASSWORD=$(openssl rand -base64 24)
   echo $NEW_PASSWORD
   
   # Update the password on RabbitMQ
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl change_password admin '$NEW_PASSWORD'"
   
   # Update the password in Vault
   safe set secret/<env>/rabbitmq/rabbitmq/admin/management password="$NEW_PASSWORD"
   ```

## Advanced Troubleshooting

### Queue Synchronization Issues

**Symptoms**:
- Unsynchronized queue warnings in logs
- Message loss after node failures
- High network usage during synchronization

**Troubleshooting Steps**:

1. **Check queue synchronization status**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl list_queues name slave_pids synchronised_slave_pids"
   ```

2. **Enable automatic synchronization mode** (use with caution, may impact performance):
   ```bash
   # For specific vhost
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl set_policy ha-sync --apply-to queues --priority 1 '.*' '{\"ha-mode\":\"all\",\"ha-sync-mode\":\"automatic\"}' -p <vhost>"
   ```

3. **Manually synchronize important queues**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl sync_queue <queue_name> -p <vhost>"
   ```

### Disk Space Alerts

**Symptoms**:
- Disk space alarms in RabbitMQ logs
- Publishers blocked due to disk alarms
- BOSH persistent disk running out of space

**Troubleshooting Steps**:

1. **Check disk usage**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "df -h /var/vcap/store"
   ```

2. **Identify disk space usage by queues**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl list_queues name messages message_bytes_persistent"
   ```

3. **Remove unused queues or expired messages**:
   ```bash
   # Delete a specific queue
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmqctl delete_queue <queue_name> -p <vhost>"
   ```

4. **Increase disk space** (requires redeploy):
   - Modify your environment to use a larger disk type:
   ```yaml
   params:
     server_disk_type: large # or larger
   ```

## Getting Help

If you're unable to resolve the issue using this guide:

1. **Check BOSH Logs**: 
   ```bash
   bosh -d <deployment-name> logs --job rabbitmq-server --index 0
   ```

2. **Generate a Support Bundle**:
   ```bash
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmq-diagnostics status > /tmp/rmq-status.txt"
   genesis do <env> -- ssh rabbitmq/0 -c "rabbitmq-diagnostics report > /tmp/rmq-report.txt"
   ```

3. **Contact Support**: Provide the following information:
   - Genesis Kit version
   - Deployment environment YML (redact secrets)
   - Error messages and logs
   - Steps already taken to troubleshoot