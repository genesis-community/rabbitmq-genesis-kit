# vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
package Genesis::Hook::CloudConfig::RabbitMQ;

use v5.20;
use warnings; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw//;
use JSON::PP;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  return 1 if $self->completed;

  my $server_network = $self->env->lookup('params.server_network', 'rabbitmq');
  my $proxy_network = $self->env->lookup('params.proxy_network', 'rabbitmq');
  my $broker_network = $self->env->lookup('params.broker_network', 'rabbitmq');

  my $server_vm_type = $self->env->lookup('params.server_vm_type', 'rabbitmq');
  my $proxy_vm_type = $self->env->lookup('params.proxy_vm_type', 'small');
  my $broker_vm_type = $self->env->lookup('params.broker_vm_type', 'small');

  my $server_disk_type = $self->env->lookup('params.server_disk_type', 'rabbitmq');

  my $config = $self->build_cloud_config({
    'networks' => [
      $self->network_definition($server_network, strategy => 'ocfp',
        dynamic_subnets => {
          allocation => {
            size => 0,
            statics => 3,
          },
          cloud_properties_for_iaas => {
            openstack => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default']
            },
            aws => {
              'subnet' => $self->network_reference('subnet_id')
            },
          },
        },
      ),
      $self->network_definition($proxy_network, strategy => 'ocfp',
        dynamic_subnets => {
          allocation => {
            size => 0,
            statics => 1,
          },
          cloud_properties_for_iaas => {
            openstack => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default']
            },
            aws => {
              'subnet' => $self->network_reference('subnet_id')
            },
          },
        },
      ),
      $self->network_definition($broker_network, strategy => 'ocfp',
        dynamic_subnets => {
          allocation => {
            size => 0,
            statics => 1,
          },
          cloud_properties_for_iaas => {
            openstack => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default']
            },
            aws => {
              'subnet' => $self->network_reference('subnet_id')
            },
          },
        },
      ),
    ],
    'vm_types' => [
      $self->vm_type_definition($server_vm_type,
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.large',
              prod => 'm1.xlarge'
            }, 'm1.large'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 32 # in gigabytes
            },
          },
          aws => {
            'instance_type' => $self->for_scale({
              dev => 'm5.large',
              prod => 'm5.xlarge'
            }, 'm5.large'),
            'ephemeral_disk' => {
              'size' => 25000 # in megabytes
            },
          },
        },
      ),
      $self->vm_type_definition($proxy_vm_type,
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 16 # in gigabytes
            },
          },
          aws => {
            'instance_type' => $self->for_scale({
              dev => 'm2.small',
              prod => 'm4.large'
            }, 'm2.small'),
            'ephemeral_disk' => {
              'size' => 25000 # in megabytes
            },
          },
        },
      ),
      $self->vm_type_definition($broker_vm_type,
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.small',
              prod => 'm1.medium'
            }, 'm1.small'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 16 # in gigabytes
            },
          },
          aws => {
            'instance_type' => $self->for_scale({
              dev => 'm2.small',
              prod => 'm4.xlarge'
            }, 'm2.small'),
            'ephemeral_disk' => {
              'size' => 25000 # in megabytes
            },
          },
        },
      ),
    ],
    'disk_types' => [
      $self->disk_type_definition($server_disk_type,
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(10),
            prod => gigabytes(20)
          }, gigabytes(10)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf6',
          },
          aws => {
            # AWS uses bare disk size in megabytes
            disk_size => $self->for_scale({
              dev => 50000,
              prod => 50000
            }, 50000),
          },
        },
      ),
    ],
  });

  $self->done($config);

	return 1;

}

1;
