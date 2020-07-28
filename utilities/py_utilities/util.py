import subprocess
import syslog

import requests


def sys_call(cmd_str, shell=True, print_stdout=False):
    proc = subprocess.Popen(
        cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        stdin=subprocess.PIPE, shell=shell
    )

    if print_stdout:
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            print(line.decode())
            line_err = proc.stderr.readline()
            if line_err:
                print(line_err.decode())

    return proc.stdout.read().decode(), proc.stderr.read().decode()


def log_error(st):
    print(st)
    syslog.syslog(syslog.LOG_ERR, st)


def get_project_info():
    resp = requests.get(
        'http://metadata.google.internal/computeMetadata/v1/instance/attributes/project-info',
        headers={'Metadata-Flavor': 'Google'}
    )
    if resp.status_code != 200:
        log_error('error: failed to retrieve project-info from computeMetadata')
        return None
    return resp.json()
