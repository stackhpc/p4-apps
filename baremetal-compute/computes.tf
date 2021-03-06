terraform {
  required_version = ">= 0.12, < 0.13"
}

provider "openstack" { # uses clouds.yml
  cloud = local.config.cloud.name
  version = "~> 1.25"
}

locals {
  config = yamldecode(file("../config/deploy.yml"))
  tf_dir = "${data.external.tf_control_hostname.result.hostname}:${path.cwd}"
  cluster_key_name = replace(slice(split(" ", chomp(file(local.config.cluster.keyfile))),2, 3)[0], "/\\W/", "-") # use key commend with "unsafe" chars replaced
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

data "external" "os_config" {
  program = ["../tf_scripts/os_config.py"]
  query = {
    cloud = local.config.cloud.name
  }
}


resource "openstack_identity_application_credential_v3" "compute_cred" {

  name = "${local.config.cluster.name}_${local.config.cluster.compute.name}"
  description = "allow compute nodes to call openstack server rebuild"
  # access_rules { # requires Train or above, didn't work anyway
  #     path = "/v3/servers/{server_id}/action"
  #     method = "POST"
  #     service  = "compute"
  # TODO: consider adding expires_at
  #}
}


resource "openstack_compute_instance_v2" "compute" {

  for_each = data.external.openstack_baremetal.result

  name = "${local.config.cluster.name}-${local.config.cluster.compute.name}-${each.key}"
  image_name = local.config.cluster.compute.image
  flavor_name = local.config.cluster.compute.flavor
  key_pair = local.cluster_key_name
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

  provisioner "file" {
    content = templatefile("${path.module}/clouds.tpl",
                            {
                              "os_config": data.external.os_config.result
                              "app_cred": openstack_identity_application_credential_v3.compute_cred
                            },
                          )
    destination = "clouds.yaml" # in centos home
  }

  provisioner "remote-exec" {
      inline = [
        "sudo mkdir -p /etc/openstack",
        "sudo cp clouds.yaml /etc/openstack/",
        "sudo chmod -R u=r,og= /etc/openstack/",
        "rm clouds.yaml"
      ]
  }

  connection {
    type = "ssh"
    user = local.config.cluster.user
    private_key = file(trimsuffix(local.config.cluster.keyfile, ".pub"))
    host = self.network[0].fixed_ip_v4
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
  filename = "${path.module}/../inventory/compute"
}
