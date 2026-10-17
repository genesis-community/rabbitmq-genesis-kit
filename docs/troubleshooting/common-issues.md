# Troubleshooting Common RabbitMQ Issues

This guide covers common issues you might encounter with your RabbitMQ Genesis Kit deployment and how to troubleshoot them.

## How the Examples Reach the VMs

The kit has no addon for running commands on its VMs, so every example here uses the Genesis `bosh` command. It runs the BOSH CLI against the environment's deployment, and we run it from the environment's directory. The examples call the environment `my-env`, so substitute your own name.

The kit deploys three instance groups. The `rmq-server` group holds the RabbitMQ nodes, the `haproxy` group holds the proxy, and the `rmq-broker` group holds the service broker when the `broker` feature is on. The `genesis my-env bosh instances` command lists them with their addresses.

On a server node, the `rabbitmqctl` and `rabbitmq-diagnostics` tools live under `/var/vcap/packages/rabbitmq-server/bin`, and the `bin/env` script of the `rabbitmq-server` job adds that directory and the Erlang directory to `PATH`. The Erlang cookie belongs to the `vcap` user. For that reason every RabbitMQ example runs as `vcap` after it sources `bin/env`, in this form.

```bash
genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl cluster_status'"
```

The log directories under `/var/vcap/sys/log` belong to `vcap` and carry no access for other users. A log example therefore expands its `*.log` pattern inside `sudo bash -c`, because a pattern that the login shell expands matches nothing.

Where an example needs a password, we read it from a prompt on the VM or send it through `curl -K`, so the password never appears on a command line or in the process list. We never pass `-k` to curl. We give curl the management CA and use `--resolve` to verify the certificate name `rabbitmq-mgmt` while it connects to an address.

## Deployment Issues

### Genesis Deploy Fails During Manifest Generation

**Symptoms**

Genesis reports errors during the manifest generation phase, and the deployment never reaches BOSH.

**Possible causes**

1. Missing required parameters

2. Feature conflicts

3. Genesis Vault access issues

4. Cloud config inconsistencies

**Troubleshooting steps**

1. Check the environment against the kit's requirements.

   ```bash
   genesis my-env check
   ```

2. Check feature compatibility.

   Review the [Feature Compatibility Matrix](../../MANUAL.md#feature-compatibility-matrix), and make sure you are not using conflicting features, such as `no-rmq-tls` and `provided-rmq-cert`.

3. Validate Vault access.

   The first command tests the connection to Vault. The second command checks that the management password exists without printing it.

   ```bash
   safe get secret/handshake
   safe exists secret/<your/env>/rabbitmq/rabbitmq/admin/management:password && echo present
   ```

4. Check that the Genesis version is compatible with the kit.

   ```bash
   genesis -v
   ```

### BOSH Deployment Fails

**Symptoms**

Genesis creates the manifest, but the BOSH deployment fails with errors in the deploy output.

**Possible causes**

1. Network configuration issues

2. Resource constraints

3. VM provisioning failures

4. Release version issues

**Troubleshooting steps**

1. Check the BOSH task logs.

   ```bash
   genesis my-env bosh tasks --recent=5
   genesis my-env bosh task <task-id> --debug
   ```

2. Verify the cloud config.

   A Genesis 3 environment uses named cloud configs, so the plain `bosh cloud-config` command reports that there is none. List the configs, then show the one that belongs to the deployment.

   ```bash
   genesis my-env bosh configs --type=cloud
   genesis my-env bosh config --type=cloud --name=<config-name>
   genesis my-env manifest | grep -E 'networks:|vm_type:|disk_type:|azs:'
   ```

3. Check infrastructure capacity.

   Make sure the IaaS has enough CPU, memory, disk, and IP addresses, and check the VM quotas and service limits.

4. Check release compatibility.

   List the uploaded releases and confirm that the versions the manifest names exist.

   ```bash
   genesis my-env bosh releases
   ```

## Runtime Issues

### RabbitMQ Nodes Fail to Cluster

**Symptoms**

Some nodes start in standalone mode, the nodes don't join the cluster, or `rabbitmqctl cluster_status` shows missing nodes.

**Possible causes**

1. Network connectivity issues between nodes

2. Erlang cookie mismatch

3. Node name resolution problems

4. Different RabbitMQ versions

**Troubleshooting steps**

1. Check the cluster status on each node.

   Repeat the command for each of the other server nodes, such as `rmq-server/1` and `rmq-server/2`.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl cluster_status'"
   ```

2. Verify that the Erlang cookie matches on every node.

   The cookie is a secret, so we compare a short fingerprint of it and never print the cookie. The three values must be identical.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo sha256sum /var/vcap/store/rabbitmq/.erlang.cookie | cut -c1-12"
   genesis my-env bosh ssh rmq-server/1 -c "sudo sha256sum /var/vcap/store/rabbitmq/.erlang.cookie | cut -c1-12"
   genesis my-env bosh ssh rmq-server/2 -c "sudo sha256sum /var/vcap/store/rabbitmq/.erlang.cookie | cut -c1-12"
   ```

3. Test network connectivity between the nodes.

   Take the address of the other node from `genesis my-env bosh instances`.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "ping -c 3 <address-of-rmq-server/1>"
   ```

4. Check the logs for clustering errors.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo bash -c 'tail -n 200 /var/vcap/sys/log/rabbitmq-server/*.log'"
   ```

5. Rejoin a node that stays out of the cluster.

   This step changes state. The `reset` command deletes all data on the node you run it on, so use it only on a node that has fallen out of the cluster. Take the node name of a healthy node from the `Running Nodes` list in the cluster status, because the kit names nodes `rabbit@` followed by a hash.

   ```bash
   genesis my-env bosh ssh rmq-server/1 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl stop_app; rabbitmqctl reset; rabbitmqctl join_cluster <healthy-node-name>; rabbitmqctl start_app'"
   ```

### High Memory Usage and Memory Alarms

**Symptoms**

RabbitMQ raises memory alarms and blocks publishers. The node log, under `/var/vcap/sys/log/rabbitmq-server`, reports memory pressure.

**Possible causes**

1. Too many queued messages

2. Too many connections

3. Insufficient memory allocation

4. Memory leaks in plugins

**Troubleshooting steps**

1. Check for active alarms and the memory figures.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmq-diagnostics check_local_alarms'"
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmq-diagnostics status | grep -A 5 -i memory'"
   ```

2. Identify the memory-intensive queues.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl list_queues name messages memory consumers'"
   ```

3. Count the connections. The count includes two header lines.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl list_connections | wc -l'"
   ```

4. Review the memory watermark settings.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl environment | grep vm_memory'"
   ```

5. Mitigate the pressure.

   - Delete unused queues.

   - Set a message TTL on queues that can lose old messages.

   - Close idle connections.

   - Move `server_vm_type` to a larger size.

### Service Broker Issues

These examples apply only when the `broker` feature is on, because otherwise the deployment has no `rmq-broker` instance.

**Symptoms**

The `register-broker` addon fails, the CF marketplace doesn't show the RabbitMQ service, or service instance creation or binding fails.

**Possible causes**

1. Broker connectivity issues with Cloud Foundry

2. Authentication failures

3. TLS or certificate problems

4. Broker connectivity issues with RabbitMQ

**Troubleshooting steps**

1. Check the broker process.

   The broker job runs under monit.

   ```bash
   genesis my-env bosh ssh rmq-broker/0 -c "sudo monit summary"
   ```

2. Read the broker logs.

   ```bash
   genesis my-env bosh ssh rmq-broker/0 -c "sudo bash -c 'tail -n 200 /var/vcap/sys/log/rabbitmq-service-broker/*.log'"
   ```

3. Test the catalog endpoint.

   The broker listens on plain HTTP at `127.0.0.1:4567`, and HAProxy on the broker VM terminates TLS on port 4566. A call to the loopback port needs no CA file. The broker username is `broker` unless you changed `params.broker_username`, and the password is in Vault at `secret/<your/env>/rabbitmq/broker/auth:password`. We open an interactive session and read the password from a prompt.

   ```bash
   genesis my-env bosh ssh rmq-broker/0
   read -rsp 'Broker password: ' BROKER_PASSWORD; echo
   curl -sS -K <(printf 'user = "broker:%s"\n' "$BROKER_PASSWORD") http://localhost:4567/v2/catalog
   unset BROKER_PASSWORD
   ```

4. Check Cloud Foundry connectivity.

   ```bash
   genesis my-env bosh ssh rmq-broker/0 -c "curl -sS -o /dev/null -w '%{http_code}\n' https://api.<cf-system-domain>/"
   ```

5. Verify the broker registration from a CF admin session.

   ```bash
   cf service-brokers | grep p-rabbitmq
   ```

### HAProxy Issues

**Symptoms**

Clients can't connect through the HAProxy frontend, the management UI is unreachable, or clients see connection refused errors.

**Possible causes**

1. HAProxy configuration issues

2. Certificate problems on the TLS endpoints

3. Backend RabbitMQ node issues

4. Network routing problems

**Troubleshooting steps**

1. Check the HAProxy process.

   ```bash
   genesis my-env bosh ssh haproxy/0 -c "sudo monit summary"
   ```

2. Read the HAProxy logs.

   ```bash
   genesis my-env bosh ssh haproxy/0 -c "sudo bash -c 'tail -n 200 /var/vcap/sys/log/rabbitmq-haproxy/*.log'"
   ```

3. Check the frontend listeners and the backend reachability.

   HAProxy listens on ports 5671, 5672, 15671, and 15672. With the `broker` feature on, the proxy on the broker VM adds port 4566.

   ```bash
   genesis my-env bosh ssh haproxy/0 -c "sudo ss -tlnp | grep haproxy"
   genesis my-env bosh ssh haproxy/0 -c "ping -c 3 <rabbitmq-node-address>"
   ```

4. Check the certificates the proxy presents.

   The first command shows the subject and expiry of the AMQPS certificate. The second shows the validity dates of the management certificate.

   ```bash
   genesis my-env bosh ssh haproxy/0 -c "openssl s_client -connect localhost:5671 </dev/null 2>/dev/null | openssl x509 -noout -subject -enddate"
   genesis my-env bosh ssh haproxy/0 -c "openssl s_client -connect localhost:15671 </dev/null 2>/dev/null | openssl x509 -noout -dates"
   ```

## Management UI Issues

### Cannot Access Management UI

**Symptoms**

You can't reach the management UI at `https://<mgmt_domain>:15671`, and the browser shows connection errors.

**Possible causes**

1. DNS resolution issues

2. TLS certificate problems

3. HAProxy configuration issues

4. Management listener not running

**Troubleshooting steps**

1. Verify DNS resolution.

   ```bash
   nslookup <mgmt_domain>
   ```

2. Check the TLS certificate.

   ```bash
   openssl s_client -connect <mgmt_domain>:15671 </dev/null
   ```

3. Verify that the management listener is up on a node.

   The command prints the number of HTTPS listeners, which is at least one while management TLS is on.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmq-diagnostics -q listeners | grep -c https'"
   ```

4. Test the management API from a server node.

   The server VMs hold the management CA, so curl can verify the certificate without `-k`. The command prints the HTTP status code, which is 200 when the listener answers.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "curl -sS -o /dev/null -w '%{http_code}\n' --cacert /var/vcap/jobs/rabbitmq-server/etc/management-cacert.pem --resolve rabbitmq-mgmt:15671:127.0.0.1 https://rabbitmq-mgmt:15671/"
   ```

### Authentication Failures in Management UI

**Symptoms**

You can't log in to the management UI, and it reports invalid credentials.

**Possible causes**

1. Incorrect username or password

2. User permissions issues

3. User not created properly

**Troubleshooting steps**

1. Verify the credentials.

   The management user is `management`. Its password is in Vault, and the next command prints it to your terminal.

   ```bash
   safe get secret/<your/env>/rabbitmq/rabbitmq/admin/management:password
   ```

2. Check the users on RabbitMQ.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl -q list_users | cut -f1'"
   ```

3. Reset the password if needed.

   The server job takes the password from Vault at deploy time, so a password changed only inside RabbitMQ would not last. We rotate the credential in Vault and deploy.

   ```bash
   genesis my-env rotate-secrets rabbitmq/admin/management
   genesis deploy my-env
   ```

## Advanced Troubleshooting

### Queue Replication Issues

RabbitMQ 4.x has no classic mirrored queues, so there is no queue synchronization to check or to enable. Replicated queues are quorum queues, and a quorum queue stays available while a majority of its members are online.

**Symptoms**

Queues report fewer online members than they have, messages are unavailable after a node failure, or network usage stays high after a node returns.

**Troubleshooting steps**

1. Check the type, leader, members, and online members of each queue.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl list_queues name type leader members online'"
   ```

2. Confirm that every node is running.

   The `Running Nodes` list should name all three nodes.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl cluster_status | grep -A 4 -i \"running nodes\"'"
   ```

3. Look for old mirroring policies.

   A cluster that was moved from RabbitMQ 3.x can carry `ha-mode` policies, which RabbitMQ 4.x ignores. The [upgrade section of the manual](../../MANUAL.md#clearing-the-brokers-ha-mode-operator-policies) shows how to clear them.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl list_operator_policies'"
   ```

### Disk Space Alerts

**Symptoms**

RabbitMQ logs disk space alarms, publishers are blocked by a disk alarm, or the BOSH persistent disk is running out of space.

**Troubleshooting steps**

1. Check the disk usage.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "df -h /var/vcap/store"
   ```

2. Identify the queues that hold persistent data.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl list_queues name messages message_bytes_persistent'"
   ```

3. Remove unused queues.

   This step deletes the queue and its messages.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmqctl delete_queue <queue_name> -p <vhost>'"
   ```

4. Increase the disk space, which needs a redeploy.

   Move the environment to a larger disk type.

   ```yaml
   params:
     server_disk_type: large # or larger
   ```

## Getting Help

If you can't resolve the issue with this guide, collect the following.

1. The BOSH logs for a server node.

   The command downloads an archive of the job logs into the current directory. The archive holds configuration, so keep it private.

   ```bash
   genesis my-env bosh logs rmq-server/0
   ```

2. The node status.

   ```bash
   genesis my-env bosh ssh rmq-server/0 -c "sudo -u vcap -H bash -c 'set -a; . /var/vcap/jobs/rabbitmq-server/bin/env; rabbitmq-diagnostics status'"
   ```

3. The details for the support request.

   - The Genesis kit version

   - The environment file, with secrets redacted

   - The error messages and logs

   - The steps you already took
