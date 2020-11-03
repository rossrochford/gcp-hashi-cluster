import json


def _get_available_traefik_sidecar_ports(existing_sidecars):

    existing_ports = [di['local_bind_port'] for di in existing_sidecars]

    curr_max_port = 3000
    if existing_sidecars:
        curr_max_port = max(existing_ports)

    available_ports = [v for v in range(curr_max_port + 1, 4501)] + [
        v for v in range(3000, curr_max_port) if v not in existing_ports]

    return available_ports


REQUIRED_ROUTE_KEYS = [
    'consul_service_name', 'traefik_service_name', 'routing_rule'
]

def get_traefik_sidecar_upstreams(cli):
    _, sidecar_data = cli.kv.get('traefik/_sidecar-upstreams/', recurse=True)
    existing_sidecars = [json.loads(di['Value'].decode()) for di in sidecar_data or []]
    sidecars_by_consul_name = {di['consul_service_name']: di for di in existing_sidecars}
    return existing_sidecars, sidecars_by_consul_name


def get_traefik_dashboards_ip_allowlist():

    _, data = cli.kv.get('traefik/config/dashboards-ip-allowlist')
    if data is None:
        return ['0.0.0.0/0']

    return json.loads(data['Value'].decode())


def expand_traefik_service_routes(cli):

    catalog_service_names = cli.catalog_service_names
    catalog_services = cli.catalog_services

    _, route_data = cli.kv.get('traefik/service-routes/', recurse=True)

    routes = []
    for di in route_data or []:
        try:
            route_di = json.loads(di['Value'].decode())
        except:
            continue
        if not all(k in route_di for k in REQUIRED_ROUTE_KEYS):
            # missing a required key, ignore this route
            continue
        if route_di['consul_service_name'] not in catalog_service_names:
            continue
        route_di['route_name'] = di['Key'].lstrip('traefik/service-routes/')
        routes.append(route_di)
    # routes = [json.loads(di['Value'].decode()) for di in route_data]
    # routes_by_name = {di['traefik_service_name']: di for di in routes}

    existing_sidecars, sidecars_by_consul_name = get_traefik_sidecar_upstreams(cli)

    available_sidecar_ports = _get_available_traefik_sidecar_ports(existing_sidecars)

    # assign sidecar ports to consul services, ensure assigned ports don't change unnecessarily on refresh
    sidecar_ports = {}
    for route_di in routes:
        consul_service = route_di['consul_service_name']
        if consul_service in sidecars_by_consul_name:
            port = sidecars_by_consul_name[consul_service]['local_bind_port']
        else:
            try:
                port = available_sidecar_ports.pop(0)
            except IndexError:
                break  # if we exceed 1500 consul services
        sidecar_ports[consul_service] = port

    cli.kv.delete('traefik/_sidecar-upstreams/', recurse=True)
    for consul_service, port in sidecar_ports.items():
        key = 'traefik/_sidecar-upstreams/' + consul_service
        cli.kv.put(key, json.dumps({
            'consul_service_name': consul_service, 'local_bind_port': port
        }))

    traefik_services = {di['traefik_service_name']: di for di in routes} # to remove duplicates

    cli.kv.delete('traefik/_services/', recurse=True)
    for traefik_service_name, route_di in traefik_services.items():
        consul_service = route_di['consul_service_name']
        if route_di.get('connect_enabled', True):
            addresses = [f'http://localhost:{sidecar_ports[consul_service]}/']
        else:
            addresses = catalog_services[route_di['consul_service_name']]['service_addresses']

        key = 'traefik/_services/' + traefik_service_name
        cli.kv.put(key, json.dumps({
            'traefik_service_name': traefik_service_name,
            'consul_service_name': consul_service,
            'service_addresses': addresses
        }))

    cli.kv.delete('traefik/_routes/', recurse=True)
    for i, route_di in enumerate(routes, 1):
        key = 'traefik/_routes/' + str(i) + '-' + route_di['traefik_service_name']
        cli.kv.put(key, json.dumps({
            'traefik_service_name': route_di['traefik_service_name'],
            'routing_rule': route_di['routing_rule'],
            'middlewares': route_di.get('middlewares', [])
        }))
