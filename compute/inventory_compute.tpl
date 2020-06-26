# define compute nodes for each "slurm group" (except we can't loop over these groups in tf)
[${config.cluster.name}_${config.cluster.compute.name}]
%{ for compute in computes}${compute.name} ansible_host=${compute.network[0].fixed_ip_v4} server_networks='${jsonencode({for net in compute.network: net.name => [ net.fixed_ip_v4 ] })}'
%{ endfor ~}

# this group defines *all* compute nodes for this cluster
[${config.cluster.name}_compute:children]
${config.cluster.name}_${config.cluster.compute.name}
