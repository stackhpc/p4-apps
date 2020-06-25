#!/usr/bin/env python
""" Terraform external data source to provide mapping of required baremetal nodes.

    Should be passed a json dict on stdin containing (keys/values as strings):
        cloud: name of cloud to query
        resource_class: NB this is case-sensitive!
        cluster: string to look for in instance display name to find existing nodes
        value: property to return for each node, e.g. id
        num_nodes: number of nodes to return - use a -ve value to get all available
    
    Can be used from the command-line by passing values in order above too.

    Note that:
    - `cluster` must be chosen carefully so that this is only instances in this cluster contain this string.
    - Baremetal nodes MUST have their name property set for this to be useful.

    Returns a dict describing baremetal nodes which are either already in the cluster or available to add to it,
    where:
        keys:= node.name
        values:= node.<value>
    This is suitable for using as the `for_each` value for a openstack_compute_instance_v2 resource group.
 """

from __future__ import print_function
import sys, json, pprint
import openstack
import pprint

if len(sys.argv) == 1: # using from terraform
    query = json.load(sys.stdin)
else:
    query = dict(zip(('cloud', 'resource_class', 'cluster', 'value', 'num_nodes'), sys.argv[1:]))
    pprint.pprint(query)

num_nodes = int(query['num_nodes'])
conn = openstack.connection.from_config(cloud=query['cloud'])
nodes = list(conn.baremetal.nodes(details=True, resource_class=query['resource_class']))
free_nodes = []
existing_nodes = []
for node in nodes:
    if node.provision_state == 'available':
        free_nodes.append(node)
    elif query['cluster'] in node.instance_info.get('display_name', ''):
        existing_nodes.append(node)
if len(sys.argv) != 1: # using from shell
    print('free:', ', '.join(n.name for n in free_nodes))
    print('existing:', ', '.join(n.name for n in existing_nodes))

# now make this the right length:
nodes = existing_nodes + free_nodes  # want to preserve existing, if any, so those are first
if num_nodes >= 0:
    if len(nodes) < num_nodes:
        raise ValueError('Not enough nodes available: requested %i nodes, %i existing/free' % (num_nodes, len(nodes)))
    nodes = nodes[:num_nodes]
    
if len(sys.argv) != 1: # using from shell
    print('nodes:', ', '.join(n.name for n in nodes))

result = {} # for tf, must return a json dict containing only strings as both keys and values:
for n in nodes:
    if n.name == '' or n.name is None:
        raise ValueError('node does not have name attribute set: %s' % n)
    result[n.name] = getattr(n, query['value'])
if len(sys.argv) == 1: # using from terraform
    print(json.dumps(result))
else:
    pprint.pprint(result)
