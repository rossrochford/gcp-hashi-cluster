import json

from py_utilities.util import sys_call


def main():
    metadata = json.loads(open('/etc/node-metadata.json').read())
    tokens = []

    for i in range(metadata['num_hashi_servers']):
        stdout, _ = sys_call('vault token create -policy nomad-server -period 72h -orphan -field=token')
        tokens.append(stdout)

    print(json.dumps({'nomad_vault_tokens': tokens}))


if __name__ == '__main__':
    main()
