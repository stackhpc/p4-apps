[all:vars]
ansible_user=${config.slurm_login.user}
ssh_proxy=${controls[0].network[0].fixed_ip_v4}
ansible_ssh_common_args='-C -o ControlMaster=auto -o ControlPersist=60s -o ProxyCommand="ssh ${config.slurm_login.user}@${controls[0].network[0].fixed_ip_v4} -W %h:%p"'

[slurm_control]
%{ for control in controls}${control.name} ansible_host=${control.network[0].fixed_ip_v4}
%{ endfor }

[slurm_login]
%{ for control in controls}${control.name} ansible_host=${control.network[0].fixed_ip_v4}
%{ endfor }

[slurm_compute]
%{ for compute in computes}${compute.name} ansible_host=${compute.network[0].fixed_ip_v4}
%{ endfor }


[${config.cluster_name}_${config.slurm_compute.name}:children]
slurm_compute
