import json
import os
import sys
import time

import requests


CONSUL_HTTP_ADDR = os.environ.get(
    'CONSUL_HTTP_ADDR', '127.0.0.1:8500'
)


def _get_node_name():
    with open('/etc/node-metadata.json') as file:
        return json.loads(file.read())['node_name']


def get_peers():
    url = 'http://' + CONSUL_HTTP_ADDR + '/v1/status/peers'
    try:
        resp = requests.get(url)
    except:
        return None
    if resp.status_code != 200:
        return None
    num_peers = len(resp.json())
    return num_peers


def get_leader():
    url = 'http://' + CONSUL_HTTP_ADDR + '/v1/status/leader'
    try:
        resp = requests.get(url)
        if resp.status_code != 200:
            return None
    except:
        return None
    leader = resp.content.decode().strip()
    return leader


def get_node_health(node_name):
    url = 'http://' + CONSUL_HTTP_ADDR + '/v1/health/node/' + node_name
    try:
        resp = requests.get(url)
        if resp.status_code != 200:
            return False
    except:
        return False

    resp = resp.json()
    if len(resp) == 0:
        return False

    return resp[0].get('Status') == 'passing'


def wait_for_leader_election(wait_time_seconds):

    three_peers_found = False
    leader_found = False

    for i in range(wait_time_seconds):

        if i > 0:
            if three_peers_found and leader_found:
                break
            time.sleep(1)

        if three_peers_found is False:
            num_peers = get_peers()
            if num_peers is None:
                continue
            if num_peers >= 3:
                three_peers_found = True

        if leader_found is False:
            leader = get_leader()
            if leader is None:
                continue
            if leader:
                leader_found = True

    if three_peers_found and leader_found:
        print('success')
        exit(0)
    else:
        print('failed')
        exit(1)


def wait_for_node_healthy(wait_time_seconds):

    node_name = _get_node_name()
    for i in range(wait_time_seconds):
        if i > 0:
            time.sleep(1)

        is_healthy = get_node_health(node_name)
        if is_healthy:
            print('success')
            exit(0)

    print('failed')
    exit(1)


if __name__ == '__main__':

    wait_type, wait_time_seconds = sys.argv[1:]
    wait_time_seconds = int(wait_time_seconds)

    if wait_type == 'leader-elected':
        wait_for_leader_election(wait_time_seconds)
    elif wait_type == 'node-healthy':
        wait_for_node_healthy(wait_time_seconds)

    print('error: unexpected wait_type: %s' % wait_type)
    exit(1)
