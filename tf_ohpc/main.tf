terraform {
  required_version = ">= 0.12, < 0.13"
}

# https://www.terraform.io/docs/providers/openstack/index.html
# uses clouds.yml
provider "openstack" {
  cloud = local.config.cloud
  version = "~> 1.25"
}
provider "local" {
  version = "~> 1.4"
}
provider "template" {
  version = "~> 2.1"
}

data "external" "tf_control_hostname" {
  program = ["./gethost.sh"] 
}

locals {
  config = yamldecode(file("../config/openhpc.yml"))
  tf_dir = "${data.external.tf_control_hostname.result.hostname}:${path.cwd}"
}

# TODO: separate out control/login?
resource "openstack_compute_instance_v2" "control" {

  count = local.config.slurm_login_num_nodes

  name = "${local.config.cluster_name}-control-${count.index}"
  image_name = local.config.slurm_login_image
  flavor_name = local.config.slurm_login_flavor
  key_pair = local.config.cluster_keypair
  network {
    name = local.config.cluster_net[0].net  # TODO: there must be a neater way of doing this??
  }
  # network {
  #   name = local.config.cluster_net[1].net
  # }
  # network {     # TODO: enable IB
  #   name = local.config.cluster_net[2].net
  # }
  metadata = {
    "terraform directory" = local.tf_dir
  }
}

resource "openstack_compute_instance_v2" "compute" {
  count = local.config.slurm_compute_num_nodes

  name = "${local.config.cluster_name}-compute-${count.index}"
  image_name = local.config.slurm_compute_image
  flavor_name = local.config.slurm_compute_flavor
  key_pair = local.config.cluster_keypair
  config_drive = local.config.cluster_config_drive
  network {
    name = local.config.cluster_net[0].net  # TODO: there must be a neater way of doing this??
  }
  network {
    name = local.config.cluster_net[1].net
  }
  #network {     # TODO: enable IB
  #   name = local.config.cluster_net[2].net
  # }
  metadata = {
    "terraform directory" = local.tf_dir
  }
}

# TODO: needs fixing to match `cluster_roles`:
# TODO: probably needs fixing for multiple control/login nodes
data "template_file" "inventory" {
  template = "${file("${path.module}/inventory.tpl")}"
  vars = {
      ssh_user_name = local.config.slurm_login.user
      proxy_ip = openstack_compute_instance_v2.control[0].network[0].fixed_ip_v4
      control = <<EOT
${openstack_compute_instance_v2.control[0].name} ansible_host=${openstack_compute_instance_v2.control[0].network[0].fixed_ip_v4}
EOT
      computes = <<EOT
%{ for compute in openstack_compute_instance_v2.compute}${compute.name} ansible_host=${compute.network[0].fixed_ip_v4}
%{ endfor }
EOT
      instance_prefix = local.config.cluster_name # TODO: change instance_prefix for cluster_name
      partition_name = local.config.slurm_compute.name # TODO: fix for multiple partitions, fix for indirection via "{{ openhpc_slurm_partitions }}" which tf doesn't understand
  }
  depends_on = [openstack_compute_instance_v2.control, openstack_compute_instance_v2.compute]
}

resource "local_file" "hosts" {
  content  = data.template_file.inventory.rendered
  filename = "${path.cwd}/inventory"
}

output "control_ip_addr" {
  value = openstack_compute_instance_v2.control[0].network[0].fixed_ip_v4
}