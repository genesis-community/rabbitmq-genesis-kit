rabbitmq Genesis Kit
=================

The **RabbitMQ Genesis Kit** deploys a RabbitMQ cluster and, optionally, the
CF RabbitMQ Multitenant Service Broker. Check out MANUAL.md for more
information.

Quick Start
-----------

To use it, you don't even need to clone this repository! Just run
the following (using Genesis v2):

```
# create a rabbitmq-deployments repo using the latest version of the rabbitmq kit
genesis init --kit rabbitmq

# create a rabbitmq-deployments repo using v1.0.0 of the rabbitmq kit
genesis init --kit rabbitmq/1.0.0

# create a my-rabbitmq-configs repo using the latest version of the rabbitmq kit
genesis init --kit rabbitmq -d my-rabbitmq-configs
```