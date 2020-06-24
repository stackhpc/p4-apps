from __future__ import print_function
import openstack
from time import time # todo: use monotonic if available
import json, pprint, sys

def create_nodes(conn, hostnames, networks, key, image, flavor):
    """ Create servers.

        Args:
            hostnames: list of strs
            key: str, name of keypair in OpenStack
            image: str, name of image in OpenStack
            flavor: str, name of flavor
        
        Tields `Server` objects.
    """
    image_obj = conn.compute.find_image(image)
    flavor_obj = conn.compute.find_flavor(flavor)
    network_objs = [{'uuid': conn.network.find_network(net).id} for net in ["ilab", "p3-bdn"]]
    
    for hostname in hostnames:
        server = conn.compute.create_server(
            name=hostname, image_id=image_obj.id, flavor_id=flavor_obj.id,
            networks=network_objs, key_name=key,
        )
        print(server)
        yield server

def write_inventory(conn, path, servers):
    """ TODO: """

    # wait for servers and extract IPs:
    # (this blocks on first one which is a bit poor)
    computes = {}
    for server in servers:
        server = conn.compute.wait_for_server(server)
        ips = {} #  want e.g. {'ilab':['0.0.0.0']}
        for net in server.addresses: # is e.g. {u'ilab': [{u'OS-EXT-IPS-MAC:mac_addr': u'fa:16:3e:02:36:af', u'version': 4, u'addr': u'10.60.253.75', u'OS-EXT-IPS:type': u'fixed'}], ... }
            ips[net] = [addr['addr'] for addr in server.addresses[net]]
        computes[server.hostname] = {'server_networks': ips, 'id': server.id } # NB: server.id is not the same as server.host_id!

    # write inventory
    # TODO: need to block here if another process is writing it
    inventory = {
        'all': {
            'children': {
                'compute': computes # TODO: name here might depend on group name??
            },
        }
    }
    
    pprint.pprint(inventory)
    with open(path, 'w') as f:
        json.dump(inventory, f)

def add_computes(hostnames, networks, keyname, image, flavor, path):

    # create servers
    conn = openstack.connection.from_config(cloud="alaska")
    t0 = time()
    servers = list(create_nodes(conn, hostnames, networks, keyname, image, flavor))
    t1 = time()
    print('created servers after %s seconds' % (t1 - t0)) # e.g. ~4s

    # write inventory:
    write_inventory(conn, path, servers)
    t2 = time()
    print('written %s after %s seconds' % (path, t2 - t1))

def del_computes(path):

    conn = openstack.connection.from_config(cloud="alaska")
    with open(path) as f:
        inventory = json.load(f)
    for hostname, hostinfo in inventory['all']['children']['compute'].items(): # TODO: groups?
        print('deleting %s (%s)' % (hostname, hostinfo['id']))
        conn.compute.delete_server(hostinfo['id'], force=True)
    
if __name__ == '__main__':
    
    inventory_path = 'inventory.json'
    if sys.argv[1] == 'add':
        hosts = ['sb-test-0', 'sb-test-1']
        nets = ["ilab", "p3-bdn"]
        add_computes(hosts, nets, "id-rsa-alaska", "CentOS7.8-OpenHPC", "general.v1.tiny", inventory_path)
    elif sys.argv[1] == 'del':
        del_computes(inventory_path)
        
    
    
    
