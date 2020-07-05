import subprocess


def sys_call(cmd_str, shell=True, suppress_errors=True, print_stdout=False):
    proc = subprocess.Popen(
        cmd_str, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE,
        shell=shell
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
