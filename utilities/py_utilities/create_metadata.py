from collections import defaultdict
import json
import os
import socket

import requests

HOSTING_ENV = os.environ['HOSTING_ENV']
METADATA_BASE_URL = 'http://metadata.google.internal/computeMetadata'

METADATA_URLS = [
    ('external_ip', '/v1/instance/network-interfaces/0/access-configs/0/external-ip'),
    ('instance_id', '/v1/instance/id'),
    ('instance_name', '/v1/instance/name'),
    ('instance_zone', '/v1/instance/zone'),
    ('cluster_service_project_id', '/v1/project/project-id'),
    ('node_type', '/v1/instance/attributes/node-type'),
    ('self_elect_as_consul_leader', '/v1/instance/attributes/self-elect-as-consul-leader'),
    ('num_hashi_servers', '/v1/instance/attributes/num-hashi-servers')
]


def create_metadata__vagrant():
    with open('/scripts/build/conf/vagrant-cluster.json') as file:
        cluster_hosts = json.loads(file.read())

    with open('/scripts/build/conf/project-info.json') as f:
        project_info = json.loads(f.read())

    return {
        'instance_id': os.environ['NODE_NAME'],
        'node_name': os.environ['NODE_NAME'],
        'instance_name': os.environ['NODE_NAME'],
        'node_ip': os.environ['NODE_IP'],
        'node_type': os.environ['NODE_TYPE'],
        'external_ip': os.environ['NODE_IP'],
        'consul_bind_ip': os.environ['NODE_IP'],
        'consul_address_ip': os.environ['NODE_IP'],
        'self_elect_as_consul_leader': False,
        'num_hashi_servers': 3,
        'instance_zone': 'europe-west3-a',  # spoof
        'cluster_service_project_id': project_info['cluster_service_project_id'],
        'ctp_prefix': os.environ['CTP_PREFIX'],
        'ctn_prefix': os.environ['CTN_PREFIX'],
        'ansible_groups': _get_ansible_groups(cluster_hosts),
        'hosts_by_tag': _get_hosts_by_tag(cluster_hosts)
    }


def create_metadata():

    if HOSTING_ENV == 'vagrant':
        return create_metadata__vagrant()

    metadata = {}

    for key, url in METADATA_URLS:
        if key == 'self_elect_as_consul_leader' and metadata['node_type'] != 'hashi-server':
            metadata['self_elect_as_consul_leader'] = False
            continue

        url = METADATA_BASE_URL + url
        headers = {'Metadata-Flavor': 'Google'}
        data = requests.get(url, headers=headers).content.decode().strip()

        if key == 'instance_zone':
            # 'projects/id/europe-west-a' --> 'europe-west-a'
            data = data.rsplit('/', 1)[1]
        if key == 'self_elect_as_consul_leader':
            data = (data == 'TRUE')  # convert to boolean
        if key == 'external_ip':
            data = data or None
        if key == 'num_hashi_servers':
            data = int(data)

        metadata[key] = data

    hostname = socket.gethostname()
    metadata['node_name'] = hostname
    metadata['node_ip'] = socket.gethostbyname(hostname)

    metadata['consul_bind_ip'] = metadata['node_ip']
    metadata['consul_address_ip'] = metadata['node_ip']

    metadata['ctp_prefix'] = os.environ['CTP_PREFIX']
    metadata['ctn_prefix'] = os.environ['CTN_PREFIX']

    return metadata


def _get_hosts_by_tag(cluster_hosts):
    hosts_by_tag = defaultdict(list)
    for di in cluster_hosts:
        for tag in di['tags']:
            hosts_by_tag[tag].append(di['ip'])
    return hosts_by_tag


def _get_ansible_groups(cluster_hosts):
    """
      replicates ansible grouping logic:

      hashi_server_1: "name == 'hashi-server-1'"
      hashi_servers: "(labels.node_type) == 'hashi_server'"
      hashi_clients: "(labels.node_type) == 'hashi_client'"
      traefik: "(labels.node_type) == 'traefik'"
      vault_servers: "(labels.node_type) == 'vault'"
      vault_server_1: "name == 'vault-server-1'"
    """

    node_type_to_group_name = {
        'hashi_server': 'hashi_servers',
        'hashi_client': 'hashi_clients',
        'vault': 'vault_servers',
        'traefik': 'traefik'
    }

    hosts_by_group = defaultdict(list)
    for di in cluster_hosts:
        if di['name'] == 'hashi-server-1':
            hosts_by_group['hashi_server_1'].append(di['ip'])
        if di['name'] == 'vault-server-1':
            hosts_by_group['vault_server_1'].append(di['ip'])
        group_name = node_type_to_group_name[di['node_type']]
        hosts_by_group[group_name].append(di['ip'])
    return hosts_by_group




def main():
    metadata = create_metadata()

    with open('/etc/node-metadata.json', 'w') as file:
        st = json.dumps(metadata, indent=4, separators=(',', ': '))
        file.write(st)


if __name__ == '__main__':
    main()
