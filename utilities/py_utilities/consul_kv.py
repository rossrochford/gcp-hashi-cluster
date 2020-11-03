import json
import os
import socket
import sys
import time

import consul
import requests

from py_utilities.consul_kv__traefik import expand_traefik_service_routes
from py_utilities.util import log_error, get_project_info


CTN_PREFIX = os.environ['CTN_PREFIX']
CTP_PREFIX = os.environ['CTP_PREFIX']

# may happens if CLUSTER_PROJECT_ID is blank when prefix env variable is set
assert CTP_PREFIX.strip().endswith('/') is False

PROJECT_METADATA_KEY = CTP_PREFIX + '/metadata'
PROJECT_METADATA_LOCK = CTP_PREFIX + '/metadata-lock'

# every node with have a session, this needs to be explictly created before acquiring Consul locks
CONSUL_HTTP_TOKEN = os.environ.get('CONSUL_HTTP_TOKEN')
HOSTING_ENV = os.environ['HOSTING_ENV']


def _get_consul_token_from_env():
    # this is a hack for one of the ansible scripts
    with open('/etc/environment') as file:
        lines = [s.strip() for s in file.readlines()]
        env_variables = dict([tuple(s.split('=')) for s in lines])
        env_variables = {k: v.strip().strip('"') for (k, v) in env_variables.items()}

    return env_variables.get('CONSUL_HTTP_TOKEN')


def _get_instance_name():
    if HOSTING_ENV == 'vagrant':
        return socket.gethostname()

    resp = requests.get(
        'http://metadata.google.internal/computeMetadata/v1/instance/name',
        headers={'Metadata-Flavor': 'Google'}
    )
    if resp.status_code != 200:
        log_error('error: failed to retrieve project-info from computeMetadata')
        exit(1)
    return resp.content.decode()


# sometimes these environment variables are not in the current
# shell environment but have been appended to /etc/environment
if not CONSUL_HTTP_TOKEN:
    CONSUL_HTTP_TOKEN = _get_consul_token_from_env()


class ConsulCli(object):

    def __init__(self):
        self.client = consul.Consul(token=CONSUL_HTTP_TOKEN)
        self.lock_session_id = self.get_or_create_lock_session()

    @property
    def kv(self):
        return self.client.kv

    @property
    def event(self):
        return self.client.event

    @property
    def catalog(self):
        return self.client.catalog

    @property
    def catalog_service_names(self):
        return [k for k in self.client.catalog.services()[1].keys()]

    @property
    def catalog_services(self):
        service_data = {}
        for consul_service_name in self.catalog_service_names:
            addresses = []
            for node in self.client.catalog.service(consul_service_name)[1]:
                addresses.append(
                    'http://' + node['ServiceAddress'] + ':' + str(node['ServicePort']) + '/'
                )
            service_data[consul_service_name] = {'service_addresses': addresses}

        return service_data

    def get_lock_sessions_by_name(self):
        _, sessions = self.client.Session.list(self.client.agent)
        return {di['Name']: di for di in sessions}

    def get_or_create_lock_session(self):
        instance_name = _get_instance_name()
        lock_session_name = 'project_lock_session__' + instance_name

        sessions_by_name = self.get_lock_sessions_by_name()
        if lock_session_name in sessions_by_name:
            return sessions_by_name[lock_session_name]['ID']

        # create lock session
        session_id = self.client.Session.create(
            self.client.agent, name=lock_session_name
        )
        return session_id

    def acquire(self, lock_slug):
        retries = 0
        while True:
            success = self.client.kv.put(
                lock_slug, None, acquire=self.lock_session_id
            )
            if success:
                return True
            retries += 1
            if retries > 200:
                return False
            time.sleep(1)


def acquire_project_metadata_lock(func):
    # could use this, but it isn't being maintained: https://github.com/kurtome/python-consul-lock
    def inner_func(*args, **kwargs):

        cli = ConsulCli()

        ans = None
        success = cli.acquire(PROJECT_METADATA_LOCK)
        if success is False:
            log_error('failed to acquire project lock: %s' % cli.lock_session_id)
            exit(1)

        exception_thrown = False
        try:
            ans = func(*args, **kwargs)
        except:
            exception_thrown = True
            log_error('error: exception thrown by %s' % func.__name__)
        finally:
            cli.kv.put(PROJECT_METADATA_LOCK, None, release=cli.lock_session_id)
        if exception_thrown:
            exit(1)  # quit, exception happened
        return ans

    return inner_func


@acquire_project_metadata_lock
def initialize_project_metadata(cli):
    initial_data = {
        'node_ips_by_name': {}, 'node_names_by_type': {}
    }
    cli.kv.put(PROJECT_METADATA_KEY, json.dumps(initial_data))

    project_info = get_project_info()
    if not project_info:
        return

    cli.kv.put(CTP_PREFIX + '/project-id', project_info['cluster_service_project_id'])
    cli.kv.put(CTP_PREFIX + '/region', project_info['region'])

    if HOSTING_ENV == 'vagrant':
        cli.kv.put(CTP_PREFIX + '/domain-name', 'localhost')
    else:
        cli.kv.put(CTP_PREFIX + '/domain-name', project_info['domain_name'])

    cli.kv.put(CTP_PREFIX + '/dashboard-auth', project_info['dashboard_auth'])
    cli.kv.put(CTP_PREFIX + '/hosting-env', HOSTING_ENV)

    cli.kv.put(CTP_PREFIX + '/kms-encryption-key', project_info['kms_encryption_key'])
    cli.kv.put(CTP_PREFIX + '/kms-encryption-key-ring', project_info['kms_encryption_key_ring'])


@acquire_project_metadata_lock
def _register_node_to_project(cli, node_name, node_type, node_ip):

    index, data = cli.kv.get(PROJECT_METADATA_KEY)
    project_data = json.loads(data['Value'].decode())

    project_data['node_ips_by_name'][node_name] = node_ip

    names = project_data['node_names_by_type'].get(node_type, [])
    if node_name not in names:
        project_data['node_names_by_type'][node_type] = names + [node_name]

    cli.kv.put(PROJECT_METADATA_KEY, json.dumps(project_data))


def register_node(cli):

    # we already have some metadata in this file
    with open('/etc/node-metadata.json') as file:
        metadata = json.loads(file.read())

    node_name = metadata['node_name']
    node_type = metadata['node_type']
    node_ip = metadata['node_ip']

    # set values on project level
    _register_node_to_project(cli, node_name, node_type, node_ip)

    # put values at CTN_PREFIX also:
    cli.kv.put(CTN_PREFIX + '/node-name', node_name)
    cli.kv.put(CTN_PREFIX + '/node-type', node_type)
    cli.kv.put(CTN_PREFIX + '/node-ip', node_ip)



def fire_event(cli, name, body=""):
    cli.event.fire(name, body=body)



if __name__ == '__main__':
    args = sys.argv[1:]
    action = args[0]

    if not CONSUL_HTTP_TOKEN:
        print('error: missing CONSUL_HTTP_TOKEN')
        exit(1)

    if action == 'create-lock-session':
        # ConsulCli() creates this on initialization if missing
        consul_cli = ConsulCli()
        print(consul_cli.lock_session_id)
        exit(0)

    consul_cli = ConsulCli()

    if action == 'initialize-project-metadata':
        initialize_project_metadata(consul_cli)

    elif action == 'register-node':
        register_node(consul_cli)

    elif action == 'expand-traefik-service-routes':
        expand_traefik_service_routes(consul_cli)

    else:
        exit('unexpected action: %s' % action)
