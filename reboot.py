#!/usr/bin/env python3
""" A RebootProgram for slurm which can rebuild the node running it.

    This is intended to set as the `RebootProgram` in `slurm.conf`.
    It is then triggered by slurm using something like:

        scontrol reboot [ASAP] reason="rebuild image:<image_id>" <NODES>
    
    If the reason starts with "rebuild" then the node is rebuilt; arguments to
    `openstack.compute.rebuild_server()` [1] may optionally be passed by including
    space-separated `name:value` pairs in the reason.

    If the reason does not start with "rebuild" then the node is rebooted.

    Messages and errors are logged to syslog.

    Requires:
    - Python 3 with openstacksdk module
    - The node's Openstack ID to have been set by cloud init in `/var/lib/cloud/data/instance-id`
    - An application credential:
        - with at least POST rights to /v3/servers/{server_id}/action
        - available via a clouds.yaml file containing only one cloud
    
    [1]: https://docs.openstack.org/openstacksdk/latest/user/proxies/compute.html#modifying-a-server
"""

# NB: if the app cred has limited

import json, socket, os, sys, subprocess, logging, logging.handlers, traceback
import openstack

# configure logging to syslog - by default only "info" and above categories appear
logger = logging.getLogger('syslogger')
logger.setLevel(logging.DEBUG)
handler = logging.handlers.SysLogHandler('/dev/log')
logger.addHandler(handler)

try:
    # find our short hostname (without fqdn):
    hostname = socket.gethostname().split('.')[0]

    # see why we're being rebooted:
    sinfo = subprocess.run(['sinfo', '--noheader', '--nodes=%s' % hostname, '-O', 'Reason'], stdout=subprocess.PIPE, universal_newlines=True)
    reason = sinfo.stdout.strip()

    # find server running this script:
    with open('/var/lib/cloud/data/instance-id') as f:
        instance_id = f.readline().strip()
    conn = openstack.connection.from_config()
    
    logger.info('%s (server id %s): reason=%r', __file__, instance_id, reason)

    if reason.startswith("rebuild"):
        params = dict(param.split(':') for param in reason.split()[1:])
        logger.info('%s (server id %s): rebuilding %s', __file__, instance_id, params)
        conn.compute.rebuild_server(instance_id, **params)
    else:
        logger.info('%s (server id %s): rebooting', __file__, instance_id)
        os.system('reboot')

except Exception:
    logger.error(traceback.format_exc())
    