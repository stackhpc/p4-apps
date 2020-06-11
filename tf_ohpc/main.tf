terraform {
  required_version = ">= 0.12, < 0.13"
}

# https://www.terraform.io/docs/providers/openstack/index.html
# uses clouds.yml
provider "openstack" {
  cloud = var.config.cloud
  version = "~> 1.25"
}

data "external" "tf_control_hostname" {
  program = ["./gethost.sh"] 
}

locals {
  # config = "${data.external.ansible_config.result}"
  tf_dir = "${data.external.tf_control_hostname.result.hostname}:${path.cwd}"
}

variable config {
}

resource "openstack_compute_instance_v2" "login" {

  count = var.config.slurm_login_num_nodes

  name = "${var.config.cluster_name}-login-${count.index}"
  image_name = var.config.slurm_login_image
  flavor_name = var.config.slurm_login_flavor
  key_pair = var.config.cluster_keypair
  network { # NB we only provide 1x network here
    name = var.config.cluster_net[0].net
  }
  metadata = {
    "terraform directory" = local.tf_dir
  }
}

resource "openstack_compute_instance_v2" "compute" {
  count = var.config.slurm_compute_num_nodes

  name = "${var.config.cluster_name}-compute-${count.index}"
  image_name = var.config.slurm_compute_image
  flavor_name = var.config.slurm_compute_flavor
  key_pair = var.config.cluster_keypair
  config_drive = var.config.cluster_config_drive

  dynamic "network" {
    for_each = var.config.cluster_net

    content {
      name = network.value["net"]
    }
  }

  metadata = {
    "terraform directory" = local.tf_dir
  }
}

# TODO: needs fixing to match `cluster_roles`:
# TODO: probably needs fixing for multiple control/login nodes
# TODO: needs fixing for case where creation partially fails resulting in "compute.network is empty list of object"
resource "local_file" "hosts" {
  content  = templatefile("${path.module}/inventory.tpl",
                          {
                            "config":var.config,
                            "logins":openstack_compute_instance_v2.login,
                            "computes":openstack_compute_instance_v2.compute,
                          },
                          )
  filename = "${path.cwd}/inventory"
}

output "login_ip_addr" {
  value = openstack_compute_instance_v2.login[0].network[0].fixed_ip_v4
}