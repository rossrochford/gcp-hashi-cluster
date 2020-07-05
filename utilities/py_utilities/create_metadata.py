import json
import os
import socket

import requests


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


def create_metadata():

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


def main():
    metadata = create_metadata()

    with open('/etc/node-metadata.json', 'w') as file:
        file.write(json.dumps(metadata))


if __name__ == '__main__':
    main()
