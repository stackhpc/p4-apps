#!/usr/bin/env python
import openstack

conn = openstack.connection.from_config(cloud="alaska")

nodes = list(conn.baremetal.nodes(details=True))
for node in nodes:
    print node.name, ':', node.instance_info.get('display_name', '(%s)' % node.provision_state)
    