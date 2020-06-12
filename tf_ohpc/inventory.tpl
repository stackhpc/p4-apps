[all:vars]
ansible_user=${config.slurm_login.user}
ssh_proxy=${logins[0].network[0].fixed_ip_v4}
ansible_ssh_common_args='-C -o ControlMaster=auto -o ControlPersist=60s -o ProxyCommand="ssh ${config.slurm_login.user}@${logins[0].network[0].fixed_ip_v4} -W %h:%p"'

[openstack]
localhost ansible_connection=local ansible_python_interpreter=python

%{ if config.cluster_environment_group != null }
[${ config.cluster_environment_group }:children]
openstack
cluster
%{ endif }

[cluster:children]
%{ for group in config.cluster_groups }${ config.cluster_name }_${ group.name }
%{ endfor ~}

[${config.cluster_name}_login]
%{ for login in logins}${login.name} ansible_host=${login.network[0].fixed_ip_v4} server_networks='${jsonencode({for net in login.network: net.name => [ net.fixed_ip_v4 ] })}'
%{ endfor ~}

[${config.cluster_name}_compute]
%{ for compute in computes}${compute.name} ansible_host=${compute.network[0].fixed_ip_v4} server_networks='${jsonencode({for net in compute.network: net.name => [ net.fixed_ip_v4 ] })}'
%{ endfor ~}

%{ for role in config.cluster_roles ~}
[cluster_${role.name}:children]
%{ for group in role.groups ~}
${config.cluster_name}_${group.name}
%{ endfor }
%{ endfor }