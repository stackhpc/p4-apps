P3 Appliances
=============

WIP: terraform version of p3-appliances. MOST OF THIS WILL BE OUT OF DATE UNLESS MARKED *UPDATED*.

A repo of tools for creating software-defined platforms for the ALaSKA P3 project.


- Ansible playbooks (including Galaxy roles) for integrating with OpenStack services, and creating 
  software middleware platforms on top of OpenStack infrastructure.

## Installation

It is recommended to install python dependencies in a virtual environment:

    virtualenv venv
    source venv/bin/activate
    pip install -U pip
    pip install -r requirements.txt

If SELinux is in use on the ansible control host, enable access to the
`selinux` python module from the virtualenv:

    ln -s /usr/lib64/python2.7/site-packages/selinux venv/lib/python2.7/site-packages/selinux

Download and deploy the role from Ansible Galaxy:

    ansible-galaxy install -r ansible/requirements.yml -p $PWD/ansible/roles

Deactivate the virtual environment:

    deactivate

## Usage

Prior to using stackhpc-appliances, ensure the virtual environment is activated:

    source venv/bin/activate

### ALaSKA Environments

There are two ALaSKA environments - Production and Alt-1. This repository
supports both of these environments. To use a specific environment, ensure that
any OpenStack authentication environment variables reference the correct
environment. When executing playbooks, be sure to use the correct Ansible
inventory:

* `ansible/inventory` is for production
* `ansible/inventory-alt-1` is for alt-1

The following examples use the production inventory.

### Creating Infrastructure Using Terraform

Both terraform and ansible are configured configured locally through YAML files.

As part of development these are currently split between:
- `config/deploy.yml` - only those variables needed to create the cluster nodes
- `config/openhpc.yml` - only those variables needed to configure the cluster
(i.e. there are no double-defintions)

Modify these as required.

Then, create the infrastructure using: 

    cd tf_ohpc
    terraform apply # uses tf_ohpc/openhpc.yml only

Once the infrastructure playbook has run to completion, an inventory
for the newly-created nodes will have been generated in the `ansible/`
subdirectory.  This inventory is suffixed with the value set in
`cluster_name`.  The cluster software can be deployed and configured
using another playbook (for example):

     ansible-playbook -i ansible/inventory-p4 --vault-password-file ~/alaska-vault-password -e @config/openhpc.yml -e @config/deploy.yml ansible/cluster-infra-configure.yml

TODO: Fix the double config/extravars?

**END UPDATE**


# What's New

- Only `openhpc` cluster functionality included.
- Terraform used instead of heat + stackhp.cluster-infra role.
- Only currently supports OpenHPC cluster (playbooks: `cluster-infra` and `cluster-infra-configure`)
- VM login node (only on `ilab` network - hardcoded in terraform).
- IB only configured on nodes with low latency network (as defined by `lln_name` in `ansible/group_vars/all/alaska`)
- NFS added as a a cluster filesystem option.
- FIXME: monitoring disabled.
- FIXME: sdd removed from raid array (because its broken on one node).
- Uses `actions` branch of stackhpc.openhpc role.
- Does not generate `/etc/hosts` - not needed now DNS fixed.
