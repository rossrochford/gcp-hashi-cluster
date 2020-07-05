import json
import os
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


def _get_consul_token_from_env():
    with open('/etc/environment') as file:
        lines = [s.strip() for s in file.readlines()]
        env_variables = dict([tuple(s.split('=')) for s in lines])
        env_variables = {k: v.strip().strip('"') for (k, v) in env_variables.items()}

    return env_variables.get('CONSUL_HTTP_TOKEN')


def _get_lock_session_id():
    with open('/etc/node-metadata.json') as file:
        metadata = json.loads(file.read())
    return metadata.get('consul_lock_session_id')


# sometimes these environment variables are not in the current
# shell environment but have been appended to /etc/environment
if not CONSUL_HTTP_TOKEN:
    CONSUL_HTTP_TOKEN = _get_consul_token_from_env()

LOCK_SESSION_ID = _get_lock_session_id()


cli = consul.Consul(token=CONSUL_HTTP_TOKEN)


def create_lock_session():

    with open('/etc/node-metadata.json') as file:
        metadata = json.loads(file.read())

    session_id = cli.Session.create(cli.agent, name='lock_session__' + metadata['node_name'])

    metadata['consul_lock_session_id'] = session_id

    with open('/etc/node-metadata.json', 'w') as file:
        file.write(json.dumps(metadata))

    return session_id


def _acquire(lock_slug):
    retries = 0
    while True:
        success = cli.kv.put(lock_slug, None, acquire=LOCK_SESSION_ID)
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

    def inner_func(*args, **kwargs):
        if not LOCK_SESSION_ID:
            _log_error('LOCK_SESSION_ID not found')
            exit(1)

        ans = None
        success = _acquire(PROJECT_METADATA_LOCK)
        if success is False:
            _log_error('failed to acquire consul project metadata lock: %s' % LOCK_SESSION_ID)
            exit(1)

        exception_thrown = False
        try:
            ans = func(*args, **kwargs)
        except:
            exception_thrown = True
            _log_error('error: exception thrown by %s' % func.__name__)
        finally:
            cli.kv.put(PROJECT_METADATA_LOCK, None, release=LOCK_SESSION_ID)
        if exception_thrown:
            exit(1)  # quit, exception happened
        return ans

    return inner_func


def _get_project_info():
    resp = requests.get(
        'http://metadata.google.internal/computeMetadata/v1/instance/attributes/project-info',
        headers={'Metadata-Flavor': 'Google'}
    )
    if resp.status_code != 200:
        _log_error('error: failed to retrieve project-info from computeMetadata')
        return None
    return resp.json()


@acquire_project_metadata_lock
def initialize_project_metadata():
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
def _register_node_to_project(node_name, node_type, node_ip):

    index, data = cli.kv.get(PROJECT_METADATA_KEY)
    project_data = json.loads(data['Value'].decode())

    project_data['node_ips_by_name'][node_name] = node_ip

    names = project_data['node_names_by_type'].get(node_type, [])
    if node_name not in names:
        project_data['node_names_by_type'][node_type] = names + [node_name]

    cli.kv.put(PROJECT_METADATA_KEY, json.dumps(project_data))


def register_node():

    # we already have some metadata in this file
    with open('/etc/node-metadata.json') as file:
        metadata = json.loads(file.read())

    node_name = metadata['node_name']
    node_type = metadata['node_type']
    node_ip = metadata['node_ip']

    # set values on project level
    _register_node_to_project(node_name, node_type, node_ip)

    # put values at CTN_PREFIX also:
    cli.kv.put(CTN_PREFIX + '/node-name', node_name)
    cli.kv.put(CTN_PREFIX + '/node-type', node_type)
    cli.kv.put(CTN_PREFIX + '/node-ip', node_ip)


@acquire_project_metadata_lock
def store_traefik_service_routes(route_data_filepath):
    # in case there are multiple Traefik nodes in the cluster

    existing_routes = get_traefik_service_routes()
    existing_routes_by_service_name = {di['service_name']: di for di in existing_routes}
    existing_ports = [di['local_bind_port'] for di in existing_routes]
    existing_ports.sort()

    with open(route_data_filepath) as file:
        route_data = json.loads(file.read())
        latest_routes = route_data['routes']

    max_port = 3000
    if existing_routes:
        max_port = max(existing_ports)

    available_ports = [v for v in range(max_port+1, 4501)] + [
        v for v in range(3000, max_port) if v not in existing_ports]

    # insert local_bind_ports, making sure not to change ports of existing services
    for di in latest_routes:
        if di['service_name'] in existing_routes_by_service_name:
            di['local_bind_port'] = existing_routes_by_service_name[di['service_name']]['local_bind_port']
            continue
        try:
            di['local_bind_port'] = available_ports.pop(0)
        except IndexError:
            # should never get here as long as we never exceed 1500 routes
            _log_error('no more ports available in range 3000-4500')
            exit(1)

    cli.kv.delete('traefik-service-routes/', recurse=True)
    cli.kv.delete('traefik-dashboards-ip-allowlist/', recurse=True)

    for route in latest_routes:
        cli.kv.put('traefik-service-routes/' + route['service_name'], json.dumps(route))

    # set dashboards_ip_allowlist
    allow_list = route_data.get('dashboards_ip_allowlist', ["0.0.0.0/0"])
    for i, cidr_range in enumerate(allow_list):
        cli.kv.put(
            ('traefik-dashboards-ip-allowlist/%s' % i), cidr_range
        )


def get_traefik_service_routes():

    _, route_data = cli.kv.get('traefik-service-routes/', recurse=True)
    if route_data is None:
        return []
    return [json.loads(di['Value'].decode()) for di in route_data]


if __name__ == '__main__':
    args = sys.argv[1:]
    action = args[0]

    if not CONSUL_HTTP_TOKEN:
        print('error: missing CONSUL_HTTP_TOKEN')
        exit(1)

    if action == 'create-lock-session':
        session_id = create_lock_session()
        print(session_id)
        exit(0)

    if not LOCK_SESSION_ID:
        print('error: missing CONSUL_LOCK_SESSION_ID')
        exit(1)

    if action == 'initialize-project-metadata':
        initialize_project_metadata()

    elif action == 'register-node':
        register_node()

    elif action == 'store-traefik-service-routes':
        if len(args) != 2:
            print('error: store-traefik-service-routes expects filepath of json file')
            exit(1)
        store_traefik_service_routes(args[1])
    else:
        exit('unexpected action: %s' % action)
