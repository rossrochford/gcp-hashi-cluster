import json
import os
import sys

import jinja2

from py_utilities.consul_kv import ConsulCli
from py_utilities.consul_kv__traefik import get_traefik_sidecar_upstreams


HOSTING_ENV = os.environ['HOSTING_ENV']

FILES = {
    'consul': [
        ('/scripts/services/consul/conf/agent/client.hcl.tmpl', '/etc/consul.d/client.hcl'),
        ('/scripts/services/consul/conf/agent/server.hcl.tmpl', '/etc/consul.d/server.hcl'),
        ('/scripts/services/consul/systemd/consul-server.service.tmpl', '/etc/systemd/system/consul-server.service'),
        ('/scripts/services/consul/systemd/consul-client.service.tmpl', '/etc/systemd/system/consul-client.service'),
        '/scripts/services/consul/acl/policies/consul_agent_policy.hcl',
        '/scripts/services/consul/acl/policies/shell_policies/hashi_server_1_shell_policy.hcl',
        '/scripts/services/consul/acl/policies/shell_policies/read_only_policy.hcl',
        '/scripts/services/consul/acl/policies/shell_policies/traefik_shell_policy.hcl'
    ],
    'ansible_gcp': [
        ('/scripts/build/ansible/auth.gcp.yml.tmpl', '/scripts/build/ansible/auth.gcp.yml'),
    ],
    'ansible_vagrant': [
        ('/scripts/build/ansible/ansible_hosts.tmpl', '/etc/ansible/hosts')
    ],

    'traefik': [
        ('/scripts/services/traefik/conf/traefik-consul-service.json.tmpl', '/etc/traefik/traefik-consul-service.json'),

        # we'll maintain a json file with the latest routes, this is used by operations/traefik/fetch-service-routes.sh
        # ('/scripts/services/traefik/conf/traefik-service-routes.json.tmpl', '/etc/traefik/traefik-service-routes.json')
    ]
}


def do_template_render(template_fp, json_data):
    base_path, filename = template_fp.rsplit('/', 1)
    template_loader = jinja2.FileSystemLoader(searchpath=base_path)
    template_env = jinja2.Environment(loader=template_loader, lstrip_blocks=True)
    template = template_env.get_template(filename)

    return template.render(**json_data)


def render_templates(service, extra_args):

    if service == 'ansible':
        service = 'ansible_' + HOSTING_ENV

    files = FILES[service]

    if service == 'traefik':
        consul_cli = ConsulCli()
        data = {
            'sidecar_upstreams': get_traefik_sidecar_upstreams(consul_cli)[0]
        }
    else:
        with open('/etc/node-metadata.json') as f:
            data = json.loads(f.read())

    if service.startswith('ansible'):
        # comma-separated list of instance names
        data['new_hashi_clients'] = extra_args[0].split(',') if extra_args else []

    for filepath in files:
        target_path = filepath
        if type(filepath) is tuple:
            filepath, target_path = filepath

        rendered_tmpl = do_template_render(filepath, data)

        with open(target_path, 'w') as file:
            file.write(rendered_tmpl)


if __name__ == '__main__':
    service_slug = sys.argv[1]
    extra_args = sys.argv[2:]

    if service_slug not in FILES and service_slug != 'ansible':
        exit('unexpected service name: "%s"' % service_slug)

    render_templates(service_slug, extra_args)
