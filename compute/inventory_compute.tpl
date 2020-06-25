[${config.cluster.name}_compute]
%{ for compute in computes}${compute.name} ansible_host=${compute.network[0].fixed_ip_v4} server_networks='${jsonencode({for net in compute.network: net.name => [ net.fixed_ip_v4 ] })}'
%{ endfor ~}
