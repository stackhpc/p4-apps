[all:vars]
ansible_user=${config.cluster.user}
ssh_proxy=${logins[0].network[0].fixed_ip_v4}
ansible_ssh_common_args='-C -o ControlMaster=auto -o ControlPersist=60s -o ProxyCommand="ssh ${config.cluster.user}@${logins[0].network[0].fixed_ip_v4} -W %h:%p"'

[openstack]
localhost ansible_connection=local ansible_python_interpreter=python

[${ config.cloud.name }:children] # TODO: not sure this is quite right
openstack
cluster

[cluster:children]
%{ for group in config.cluster.groups}${ config.cluster.name }_${ group }
%{ endfor ~}

[${config.cluster.name}_login]
%{ for login in logins}${login.name} ansible_host=${login.network[0].fixed_ip_v4} server_networks='${jsonencode({for net in login.network: net.name => [ net.fixed_ip_v4 ] })}'
%{ endfor ~}

%{ for role in config.cluster.roles ~}
[cluster_${role.name}:children]
%{ for group in role.groups ~}
${config.cluster.name}_${group}
%{ endfor }
%{ endfor }
