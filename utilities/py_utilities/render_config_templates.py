import json
import os
import sys

import jinja2

from py_utilities.consul_kv import get_traefik_service_routes

SCRIPTS_DIR = '/scripts/'


FILES = {
    'consul': [
        'services/consul/conf/agent/base.hcl',
        'services/consul/conf/agent/client.hcl',
        'services/consul/conf/agent/server.hcl',
        'services/consul/systemd/consul-server.service',
        'services/consul/systemd/consul-client.service',
        'services/consul/acl/policies/consul_agent_policy.hcl',
        'services/consul/acl/policies/shell_policies/hashi_server_1_shell_policy.hcl',
        'services/consul/acl/policies/shell_policies/traefik_shell_policy.hcl'
    ],
    'ansible': ['build/ansible/auth.gcp.yml'],
    'traefik': [
        ('services/traefik/traefik-service.json.tmpl', '/etc/traefik/traefik-service.json')
    ]
}


def do_template_render(template_fp, json_data):
    base_path, filename = template_fp.rsplit('/', 1)
    template_loader = jinja2.FileSystemLoader(searchpath=base_path)
    template_env = jinja2.Environment(loader=template_loader, lstrip_blocks=True)
    template = template_env.get_template(filename)

    return template.render(**json_data)


def render_all(service, files):

    if service == 'traefik':
        data = {'routes': get_traefik_service_routes()}  # note: doesn't include IP allowlist
    else:
        with open('/etc/node-metadata.json') as f:
            data = json.loads(f.read())

    for filepath in files:
        target_path = filepath
        if type(filepath) is tuple:
            filepath, target_path = filepath
        filepath = os.path.join(SCRIPTS_DIR, filepath)

        rendered_tmpl = do_template_render(filepath, data)

        with open(target_path, 'w') as file:
            file.write(rendered_tmpl)


if __name__ == '__main__':
    service = sys.argv[1]

    if service not in FILES:
        exit('unexpected service name: "%s"' % service)

    render_all(service, FILES[service])
