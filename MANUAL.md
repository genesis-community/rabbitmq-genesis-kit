# RabbitMQ Genesis Kit Manual

The **RabbitMQ Genesis Kit** deploys a RabbitMQ cluster and, optionally, the CF RabbitMQ Multitenant Service Broker.

# Base Parameters

* `rmq_domain` - (**REQUIRED**) The domain that the AMQP/MQTT/Stomp APIs will
be located. If you're not utilizing DNS to target these nodes, set this to
the static IP that the RabbitMQ proxy will be deployed to (the first static
IP in the network). If you are utilizing DNS, use the DNS hostname. This
value should _not_ include a scheme or port in the value.

* `mgmt_domain` - (_Default_: `<value of rmq_domain>) The domain that the
RabbitMQ Management API will be located at.

* `rmq_instances` - (_Default_: `3`) The number of RabbitMQ nodes in the 
cluster.

* `availability_zones` - (_Default_: `[z1]`) The AZs that VMs will be deployed 
into.

* `server_network` - (_Default_: `rabbitmq`) The network that the RabbitMQ
server VMs will be deployed in. These VMs will not typically be directly
accessed by users - these servers are proxied to from the network you choose
as the proxy network.

* `proxy_network` - (_Default_: `rabbitmq`) The network that the HAProxy which
fronts the RabbitMQ servers will be deployed in. This is effectively the edge
of your cluster, and so this must be accessible to the RabbitMQ users. It
must also be accessible to the broker's network, if you are deploying this
with a broker.

* `server_vm_type` - (_Default_: `rabbitmq`) The VM type that will be used to
size the RabbitMQ server virtual machines in the cluster.

* `proxy_vm_type` - (_Default_: `small`) The VM type that will be used to size
the HAProxy virtual machine that fronts the RabbitMQ cluster. 

* `server_disk_type` - (_Default_: `rabbitmq`) The disk type that will be
attached to the RabbitMQ server cluster nodes. The persistent disk is used to
back data for cluster configuration, queue configuration, and durable queue 
data.

* `stemcell_os` - (_Default_: `ubuntu-xenial`) The OS of the stemcell to use.

* `stemcell_version` - (_Default_: `latest`) The version of the stemcell to use.

* `check_queue_sync` - (_Default_: `false`) If true, the pre-stop script of the rabbitmq-server will wait until mirrored and quorum queues are synced before shutting down.

# Features

## `broker`

Deploys the cf-rabbitmq-multitenant-broker to allow applications within Cloud
Foundry to utilize the RabbitMQ cluster. The broker server listens on TCP 
port 4566, listening for HTTPS traffic.

### Parameters

* `broker_domain` - (**REQUIRED**) The domain that the RabbitMQ CF Broker
will be located. If you're not utilizing DNS to target these nodes, set this
to the static IP that the RabbitMQ Broker will be deployed to (the second
static IP in the broker_network). If you are utilizing DNS, use the DNS
hostname. This value should _not_ include a scheme or port in the value. This
should point to the broker or a loadbalancer fronting the broker, even if you
are using route registrar, as this value is used to populate the SANs on the
certificate that the broker serves for TLS.

* `broker_username` - (_Default_: `broker`) The username that the service broker
will accept for authentication.

* `broker_network` - (_Default_: `rabbitmq`) The network that the RabbitMQ
Multitenant Broker will be deployed into. Under normal configuration, this
network must be reachable by the CF Cloud Controller nodes. If route registrar
is configured, this must be able to reach the CF NATS nodes, and be reachable
by the CF GoRouters.

* `broker_vm_type` - (_Default_: `small`) The VM type that will be used to size
the broker virtual machine.

* `broker_name` - (_Default_: `p-rabbitmq`) The name of the broker as it will
be registered with Cloud Foundry by the broker-registrar errand.

* `service_name` - (_Default_: `p-rabbitmq`) The name of the service that will
be exposed in the catalog to Cloud Foundry.

* `ha_sync_mode` - (_Default_: `manual`) The ha-sync-mode to be configured for
vhosts created by this broker.

## `no-broker-tls`

Depends on feature `broker`.

Disables serving TLS from the service broker. This should only be needed if you
have skip_verify set to false on your Cloud Controller, and you are unable to
add the CA of the broker to the trusted cert store of the Cloud Controller VMs.

## `route-registrar`

Depends on feature `broker`.

This registers routes with over the NATS bus of the Cloud Foundry deployed by
this BOSH director, such that traffic can be forwarded to the broker and
management API from the Cloud Foundry's GoRouter. This feature is reliant on
BOSH links, so you won't be able to register routes with a Cloud Foundry
deployed by a different BOSH director.

### Parameters

* `cf_deployment` - (_Default_: `<env-name>-cf`) The name of the BOSH deployment
containing your Cloud Foundry.

* `broker_domain` - (_Default_: `rabbitmq-broker.<cf-system-domain>`) This
param already exists at the base of the kit, but specifying this feature
gives it a default value and thus makes it no longer mandatory. The value of
this parameter is what the broker will be registered and routed for with the
GoRouter.

* `mgmt_domain` - (_Default_: `rabbitmq-management.<cf-system-domain>`) 
This param already exists at the base of the kit, but specifying this feature
changes its default value. The value of this parameter is what the RabbitMQ
management API will be registered and routed for with the GoRouter.

## `nats-tls`

Depends on feature `route-registrar`

This will connect to the NATS bus over mutual TLS. You must have the nats-tls
job deployed in your Cloud Foundry deployment for this to work. This feature
requires that you configure the client certificate and client key that will
be used to connect to NATS.

### Parameters

* `nats_client_cert` - (**REQUIRED**) The certificate to present to NATS for
Mutual TLS.

* `nats_client_key` - (**REQUIRED**) The certificate to use with NATS for
Mutual TLS.

## `no-rmq-tls`

Disables TLS communications to the RabbitMQ cluster, and also between RabbitMQ
nodes.

## `no-mgmt-tls`

Disables the TLS listener for the Management API on 15671, and will instead
listen for plaintext HTTP traffic on 15672.

## `external-rmq-lb`

Stops the haproxy node which would normally front the RabbitMQ nodes from being
deployed and exposes a vm_extension to be defined in your cloud config to attach
the RabbitMQ nodes to a load balancer. Notable ports that you may want to
forward are as follows:

* `1883` - MQTT
* `5671` - AMQPS
* `5672` - AMQP
* `8883` - MQTT over TLS
* `15671` - RabbitMQ Management over HTTPS
* `15672` - RabbitMQ Management over HTTP
* `15674` - WebSTOMP
* `61613` - STOMP
* `61614` - STOMP over TLS

### vm_extensions

* `rmq_loadbalancer` - Applies to each of the rmq_server nodes. Should be used
to attach the VMs to the backend pool of a load balancer.

## `provided-rmq-cert`

This will cause the kit to not generate certificates for the RabbitMQ cluster,
and to instead require that you populate the server certificate and trusted
CA certificate at:

* `secret/<your/env>/rabbitmq/rabbitmq/certs/server:certificate`
* `secret/<your/env>/rabbitmq/rabbitmq/certs/server:key`
* `secret/<your/env>/rabbitmq/rabbitmq/certs/ca:certificate`

## `provided-mgmt-cert`

This will cause the kit to not generate certificates for the Management API,
and to instead require that you populate the server certificate and trusted
CA certificate at:

* `secret/<your/env>/rabbitmq/mgmt/certs/server:certificate`
* `secret/<your/env>/rabbitmq/mgmt/certs/server:key`
* `secret/<your/env>/rabbitmq/mgmt/certs/ca:certificate`

## `provided-broker-cert`

This will cause the kit to not generate certificates for the Service Broker,
and to instead require that you populate the server certificate and trusted
CA certificate at:

* `secret/<your/env>/rabbitmq/broker/certs/server:certificate`
* `secret/<your/env>/rabbitmq/broker/certs/server:key`

## `mqtt`

Enables the RabbitMQ MQTT plugin

## `stomp`

Enables the RabbitMQ STOMP plugin

# Available Addons

* `register-broker` - Register this broker with the Cloud Foundry in
this environment.

* `deregister-broker` - Deregister this broker from the Cloud Foundry in
this environment.

* `smoketest` - Run the smoke test errand for this deployment. This
errand will not pass unless you have route registrar enabled.
