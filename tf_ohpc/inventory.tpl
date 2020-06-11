[all:vars]
ansible_user=${config.slurm_login.user}
ssh_proxy=${logins[0].network[0].fixed_ip_v4}
ansible_ssh_common_args='-C -o ControlMaster=auto -o ControlPersist=60s -o ProxyCommand="ssh ${config.slurm_login.user}@${logins[0].network[0].fixed_ip_v4} -W %h:%p"'

[slurm_control]
%{ for login in logins}${login.name} ansible_host=${login.network[0].fixed_ip_v4}
%{ endfor }

[slurm_login]
%{ for login in logins}${login.name} ansible_host=${login.network[0].fixed_ip_v4}
%{ endfor }

[slurm_compute]
%{ for compute in computes}${compute.name} ansible_host=${compute.network[0].fixed_ip_v4}
%{ endfor }


[${config.cluster_name}_${config.slurm_compute.name}:children]
slurm_compute
