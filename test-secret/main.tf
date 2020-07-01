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

data "external" "os_config" {
  program = ["../tf_scripts/os_config.py"]
  query = {
    cloud = local.config.cloud.name
  }
}

resource "openstack_identity_application_credential_v3" "rebuild" {
  #https://www.terraform.io/docs/providers/openstack/r/identity_application_credential_v3.html

  name = "${local.config.cluster.name}_${local.config.cluster.compute.name}"
  description = "enables compute nodes to call openstack server rebuild"
  access_rules { # requires Train or above
      path = "/v3/servers/{server_id}/action"
      method = "POST"
      service  = "compute"
  # TODO: consider adding expires_at
  }
}

resource "openstack_compute_instance_v2" "compute" {

  name = "secrets-${local.config.cluster.compute.name}-0"
  image_name = local.config.cluster.compute.image
  flavor_name = "general.v1.small"
  key_pair = local.config.cluster.keypair
  config_drive = local.config.cluster.compute.config_drive
  
  network {
    name = "ilab"
  }
  
  metadata = {
    "terraform directory" = local.tf_dir,
    "cluster" = local.config.cluster.name
  }

  # user_data = templatefile("${path.module}/clouds.tpl",
  #                           {
  #                             "os_config": data.external.os_config.result
  #                             "app_cred": openstack_identity_application_credential_v3.rebuild
  #                           },
  #                         )
  user_data = "sudo mkdir -p /etc/openstack; sudo chown centos /etc/openstack"
  
  provisioner "file" { # have to use a 
    content = templatefile("${path.module}/clouds.tpl",
                            {
                              "os_config": data.external.os_config.result
                              "app_cred": openstack_identity_application_credential_v3.rebuild
                            },
                          )
    destination = "clouds.yaml" # in centos home
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/openstack",
      "sudo cp clouds.yaml /etc/openstack/",
    ]
  }

  # TODO: needs some depends-on

  connection {
    type = "ssh"
    user = local.config.cluster.user
    private_key = file("~/.ssh/id_rsa")
    host = openstack_compute_instance_v2.compute.network[0].fixed_ip_v4
  }

}

output "ip_addr" {
  value = openstack_compute_instance_v2.compute.network[0].fixed_ip_v4
}
