import json
import sys

import jinja2

from py_utilities.consul_kv import (
    get_traefik_sidecar_upstreams, get_traefik_service_routes,
    get_traefik_dashboards_ip_allowlist, ConsulCli
)


FILES = {
    'consul': [
        ('/scripts/services/consul/conf/agent/base.hcl.tmpl', '/etc/consul.d/base.hcl'),
        ('/scripts/services/consul/conf/agent/client.hcl.tmpl', '/etc/consul.d/client.hcl'),
        ('/scripts/services/consul/conf/agent/server.hcl.tmpl', '/etc/consul.d/server.hcl'),
        ('/scripts/services/consul/systemd/consul-server.service.tmpl', '/etc/systemd/system/consul-server.service'),
        ('/scripts/services/consul/systemd/consul-client.service.tmpl', '/etc/systemd/system/consul-client.service'),
        '/scripts/services/consul/acl/policies/consul_agent_policy.hcl',
        '/scripts/services/consul/acl/policies/shell_policies/hashi_server_1_shell_policy.hcl',
        '/scripts/services/consul/acl/policies/shell_policies/traefik_shell_policy.hcl'
    ],
    'ansible': ['/scripts/build/ansible/auth.gcp.yml'],

    'traefik': [
        ('/scripts/services/traefik/conf/traefik-consul-service.json.tmpl', '/etc/traefik/traefik-consul-service.json'),

        # we'll maintain a json file with the latest routes, this is used by operations/traefik/fetch-service-routes.sh
        ('/scripts/services/traefik/conf/traefik-service-routes.json.tmpl', '/etc/traefik/traefik-service-routes.json')
    ]
}


def do_template_render(template_fp, json_data):
    base_path, filename = template_fp.rsplit('/', 1)
    template_loader = jinja2.FileSystemLoader(searchpath=base_path)
    template_env = jinja2.Environment(loader=template_loader, lstrip_blocks=True)
    template = template_env.get_template(filename)

    return template.render(**json_data)


def render_templates(service, files):

    if service == 'traefik':
        consul_cli = ConsulCli()
        data = {
            'sidecar_upstreams': get_traefik_sidecar_upstreams(consul_cli),
            'traefik_routes': get_traefik_service_routes(consul_cli),
            'dashboards_ip_allowlist': get_traefik_dashboards_ip_allowlist(consul_cli)
        }
    else:
        with open('/etc/node-metadata.json') as f:
            data = json.loads(f.read())

    for filepath in files:
        target_path = filepath
        if type(filepath) is tuple:
            filepath, target_path = filepath

        rendered_tmpl = do_template_render(filepath, data)

        with open(target_path, 'w') as file:
            file.write(rendered_tmpl)


if __name__ == '__main__':
    service = sys.argv[1]

    if service not in FILES:
        exit('unexpected service name: "%s"' % service)

    render_templates(service, FILES[service])
