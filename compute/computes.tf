terraform {
  required_version = ">= 0.12, < 0.13"
}

# https://www.terraform.io/docs/providers/openstack/index.html
# uses clouds.yml
provider "openstack" {
  cloud = local.config.cloud.name
  version = "~> 1.25"
}

locals {
  config = yamldecode(file("../config/deploy.yml"))
  tf_dir = "${data.external.tf_control_hostname.result.hostname}:${path.cwd}"
}

data "external" "tf_control_hostname" {
  program = ["../tf_scripts/gethost.sh"] 
}

data "external" "openstack_baremetal" {
    program = ["../tf_scripts/baremetal.py"]

    query = {
        cloud = local.config.cloud.name
        resource_class = local.config.cluster.compute.resource_class,
        cluster = "${local.config.cluster.name}-${local.config.cluster.compute.name}-" ,
        value = "id"
        num_nodes = local.config.cluster.compute.num_nodes
    }
}

resource "openstack_compute_instance_v2" "compute" {

  for_each = data.external.openstack_baremetal.result

  name = "${local.config.cluster.name}-${local.config.cluster.compute.name}-${each.key}"
  image_name = local.config.cluster.compute.image
  flavor_name = local.config.cluster.compute.flavor
  key_pair = local.config.cluster.keypair
  config_drive = local.config.cluster.compute.config_drive
  availability_zone = "nova::${each.value}" # TODO: availability zone should probably be from config too?s

  dynamic "network" {
    for_each = local.config.cluster.compute.networks

    content {
      name = network.value
    }
  }

  metadata = {
    "terraform directory" = local.tf_dir,
    "cluster" = local.config.cluster.name
  }
}

# TODO: needs fixing for case where creation partially fails resulting in "compute.network is empty list of object"
resource "local_file" "hosts" {
  content  = templatefile("${path.module}/inventory_compute.tpl",
                          {
                            "config":local.config,
                            "computes":openstack_compute_instance_v2.compute,
                          },
                          )
  filename = "${path.module}/../inventory/inventory_compute"
}
