import json
import sys

from invoke import run as shell_run


# confusingly, in the V2 API you write secrets to 'secret/my-key' but
# read from 'secret/data/my-key' (https://github.com/hashicorp/vault/issues/7161)

def write_secrets(json_filepath):
    # for each secret, run commands:
    #   $ vault kv put <secret_path> key1=val1 key2=val2
    #   $ vault kv metadata put -max-versions 2 <secret_path>

    with open(json_filepath) as file:
        secrets_data = json.loads(file.read())

    for secret_path, values in secrets_data.items():

        cmd = "vault kv put " + secret_path
        for key, val in values.items():
            cmd = cmd + ' %s=%s' % (key, val)

        cmd2 = 'vault kv metadata put -max-versions 2 ' + secret_path

        shell_run(cmd)
        shell_run(cmd2)


# to fetch data run:
#    vault kv get -field=oauth2_key secret/nomad/browserchunk/social-auth-google


if __name__ == '__main__':
    action = sys.argv[1]
    if action == 'write-secrets':
        filepath = sys.argv[2]
        write_secrets(filepath)
