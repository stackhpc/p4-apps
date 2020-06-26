P4-Apps
=============

Work-in-progress for a terraform-defined Slurm cluster with:
- VM login nodes
- Baremetal or VM compute nodes
- Slurm-driven reimaging
- Resizing of compute nodes
- Flexible, ansible-based deployment of addtional cluster functionality e.g. filesystems, monitoring etc.

Not all the above currently works.

## Installation

**THIS NEEDS UPDATING**

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

### Creating Infrastructure Using Terraform

Both terraform and ansible are configured configured locally through YAML files.

As part of development these are currently split between:
- `config/deploy.yml` - only those variables needed to create the cluster nodes
- `config/openhpc.yml` - only those variables needed to configure the cluster
(i.e. there are no double-defintions)


1. Modify these as required.

2. Create the head node using:

        cd infra
        terraform apply # uses tf_ohpc/deploy.yml only

3. Create the compute nodes using:

        cd ../computes
        terraform apply # uses tf_ohpc/deploy.yml only

These will generate inventory files in the `inventory/` directory.

4. Deploy and configure software using:

        cd <repo root>
        ansible-playbook -i inventory/ --vault-password-file ~/alaska-vault-password -e @config/openhpc.yml -e @config/deploy.yml ansible/cluster.yml

# Selected changes from p3-appliances
Aside from functionality specifically listed above:
- Only manages OpenHPC cluster.
- Uses terraform instead of Heat + cluster-infra role.
- Uses `actions` branch of stackhpc.openhpc role.
- Does not generate `/etc/hosts` - not needed now DNS fixed.

# TODO
- FIXME: Remove double config/extravars in ansible
- FIXME: monitoring is disabled
- FIXME: sdd removed from raid array (because its broken on one node).
