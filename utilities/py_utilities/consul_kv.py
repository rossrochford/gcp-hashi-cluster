import json
import os
import socket
import sys
import syslog
import time

import consul
import requests


CTN_PREFIX = os.environ['CTN_PREFIX']
CTP_PREFIX = os.environ['CTP_PREFIX']

PROJECT_METADATA_KEY = CTP_PREFIX + '/metadata'
PROJECT_METADATA_LOCK = CTP_PREFIX + '/metadata-lock'

# every node with have a session, this needs to be explictly created before acquiring Consul locks
CONSUL_HTTP_TOKEN = os.environ.get('CONSUL_HTTP_TOKEN')

RUN_ENV = "prod"


def _get_consul_token_from_env():
    with open('/etc/environment') as file:
        lines = [s.strip() for s in file.readlines()]
        env_variables = dict([tuple(s.split('=')) for s in lines])
        env_variables = {k: v.strip().strip('"') for (k, v) in env_variables.items()}

    return env_variables.get('CONSUL_HTTP_TOKEN')


def _get_project_info():
    resp = requests.get(
        'http://metadata.google.internal/computeMetadata/v1/instance/attributes/project-info',
        headers={'Metadata-Flavor': 'Google'}
    )
    if resp.status_code != 200:
        _log_error('error: failed to retrieve project-info from computeMetadata')
        return None
    return resp.json()


def _get_instance_name():
    if RUN_ENV == 'dev':
        return socket.gethostname()

    resp = requests.get(
        'http://metadata.google.internal/computeMetadata/v1/instance/name',
        headers={'Metadata-Flavor': 'Google'}
    )
    if resp.status_code != 200:
        _log_error('error: failed to retrieve project-info from computeMetadata')
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


def _log_error(st):
    print(st)
    syslog.syslog(syslog.LOG_ERR, st)


def acquire_project_metadata_lock(func):
    # could use this, but it isn't being maintained: https://github.com/kurtome/python-consul-lock
    def inner_func(*args, **kwargs):

        cli = ConsulCli()

        ans = None
        success = cli.acquire(PROJECT_METADATA_LOCK)
        if success is False:
            _log_error('failed to acquire project lock: %s' % cli.lock_session_id)
            exit(1)

        exception_thrown = False
        try:
            ans = func(*args, **kwargs)
        except:
            exception_thrown = True
            _log_error('error: exception thrown by %s' % func.__name__)
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

    project_info = _get_project_info()
    if project_info:
        cli.kv.put(CTP_PREFIX + '/project-id', project_info['cluster_service_project_id'])
        cli.kv.put(CTP_PREFIX + '/region', project_info['region'])
        cli.kv.put(CTP_PREFIX + '/domain-name', project_info['domain_name'])
        cli.kv.put(CTP_PREFIX + '/dashboard-auth', project_info['dashboard_auth'])

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


'''
def get_available_traefik_sidecar_ports(existing_routes):

    existing_routes = get_traefik_service_routes()

    existing_ports = [di['local_bind_port'] for di in existing_routes]
    existing_ports.sort()

    max_port = 3000
    if existing_routes:
        max_port = max(existing_ports)

    available_ports = [v for v in range(max_port+1, 4501)] + [
        v for v in range(3000, max_port) if v not in existing_ports]

    return available_ports
'''


def get_available_traefik_sidecar_ports(cli):

    existing_sidecars = get_traefik_sidecar_upstreams(cli)
    existing_ports = [di['local_bind_port'] for di in existing_sidecars]

    max_port = 3000
    if existing_sidecars:
        max_port = max(existing_ports)

    available_ports = [v for v in range(max_port+1, 4501)] + [
        v for v in range(3000, max_port) if v not in existing_ports]

    return available_ports


def fire_event(cli, name, body=""):
    cli.event.fire(name, body="")


'''
@acquire_project_metadata_lock
def append_traefik_service_routes(route_data_or_filepath):

    if type(route_data_or_filepath) is str:
        with open(route_data_or_filepath) as file:
            route_data = json.loads(file.read())['routes']
    else:
        route_data = route_data_or_filepath

    existing_routes = get_traefik_service_routes()
    existing_routes_by_service_name = {
        di['service_name']: di for di in existing_routes
    }
    available_ports = get_available_traefik_sidecar_ports(existing_routes)

    for di in route_data:
        if di['service_name'] in existing_routes_by_service_name:
            continue
        try:
            di['local_bind_port'] = available_ports.pop(0)
        except IndexError:
            # should never get here as long as we never exceed 1500 routes
            _log_error('no more ports available in range 3000-4500')
            exit(1)

        cli.kv.put('traefik-service-routes/' + di['service_name'], json.dumps(di))

    cli.event.fire("traefik-routes-updated")
'''


@acquire_project_metadata_lock
def overwrite_traefik_service_routes(cli, route_data_filepath):

    existing_routes = get_traefik_service_routes(cli)
    existing_sidecars = get_traefik_sidecar_upstreams(cli)
    existing_routes_by_name = {di['traefik_service_name']: di for di in existing_routes}
    existing_sidecars_by_name = {di['consul_service_name']: di for di in existing_sidecars}

    with open(route_data_filepath) as file:
        route_data = json.loads(file.read())

    latest_routes = route_data['routes']
    latest_routes_by_name = {di['traefik_service_name']: di for di in latest_routes}
    latest_consul_services = [di['consul_service_name'] for di in latest_routes]

    # find obsolete routes and sidecars
    routes_to_remove, sidecars_to_remove = [], []
    for di in existing_routes:
        if di['traefik_service_name'] not in latest_routes_by_name:
            routes_to_remove.append(di['traefik_service_name'])
        if di['consul_service_name'] not in latest_consul_services:
            sidecars_to_remove.append(di['consul_service_name'])

    available_sidecar_ports = get_available_traefik_sidecar_ports(cli)

    # add sidecar upstreams and gather ports
    for di in route_data['routes']:
        consul_service = di['consul_service_name']

        # if consul_service in existing_sidecars_by_name:
        #    sidecar_ports[consul_service] = existing_sidecars_by_name[consul_service]  # di['local_bind_port']
        if consul_service not in existing_sidecars_by_name:
            try:
                port = available_sidecar_ports.pop(0)
            except IndexError:
                # should never get here as long as we never exceed 1500 routes
                _log_error('no more ports available in range 3000-4500')
                exit(1)

            di = {'consul_service_name': consul_service, 'local_bind_port': port}

            key = 'traefik-sidecar-upstreams/' + consul_service
            cli.kv.put(key, json.dumps(di))

            existing_sidecars_by_name[consul_service] = di

    # add/update routes
    for di in route_data['routes']:
        if di['traefik_service_name'] in existing_routes_by_name:
            if di == existing_routes_by_name[di['traefik_service_name']]:
                continue  # no update required

        if 'routing_rule' not in di:
            print('no "routing_rule" found, skipping route for: %s' % di['consul_service_name'])
            continue

        middlewares = di.get('middlewares', [])
        if 'source-ratelimit' in middlewares:
            middlewares.append('source-ratelimit')

        di = {
            'traefik_service_name': di['traefik_service_name'],
            'consul_service_name': di['consul_service_name'],
            'routing_rule': di['routing_rule'],
            'middlewares': middlewares,
            'local_bind_port': existing_sidecars_by_name[di['consul_service_name']]['local_bind_port'],
        }
        key = 'traefik-service-routes/' + di['traefik_service_name']
        cli.kv.put(key, json.dumps(di))

    # delete routes and sidecars
    for traefik_service_name in routes_to_remove:
        cli.kv.delete('traefik-service-routes/' + traefik_service_name)

    for consul_service_name in sidecars_to_remove:
        cli.kv.delete('traefik-sidecar-upstreams/' + consul_service_name)

    # set dashboards_ip_allowlist
    cli.kv.delete('traefik-dashboards-ip-allowlist/', recurse=True)
    allow_list = route_data.get('dashboards_ip_allowlist', ["0.0.0.0/0"])
    for i, cidr_range in enumerate(allow_list):
        cli.kv.put(
            ('traefik-dashboards-ip-allowlist/%s' % i), cidr_range
        )

    cli.event.fire("traefik-routes-updated")


def get_traefik_dashboards_ip_allowlist(cli):
    _, data = cli.kv.get('traefik-dashboards-ip-allowlist/', recurse=True)
    if data is None:
        return []
    # Values are cidr_range strings
    return [di['Value'].decode() for di in data]


def get_traefik_service_routes(cli):
    _, route_data = cli.kv.get('traefik-service-routes/', recurse=True)
    if route_data is None:
        return []
    return [json.loads(di['Value'].decode()) for di in route_data]


def get_traefik_sidecar_upstreams(cli):
    _, route_data = cli.kv.get('traefik-sidecar-upstreams/', recurse=True)
    if route_data is None:
        return []
    return [json.loads(di['Value'].decode()) for di in route_data]


if __name__ == '__main__':
    args = sys.argv[1:]
    action = args[0]

    if RUN_ENV == "prod" and not CONSUL_HTTP_TOKEN:
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

    elif action == 'overwrite-traefik-service-routes':
        if len(args) != 2:
            print('error: overwrite-traefik-service-routes expects a filepath argument')
            exit(1)
        overwrite_traefik_service_routes(consul_cli, args[1])

    else:
        exit('unexpected action: %s' % action)

'''
elif action == 'append-traefik-service-routes':
    if len(args) != 2:
        print('error: append-traefik-service-routes expects a filepath argument')
        exit(1)
    append_traefik_service_routes(args[1])
'''
