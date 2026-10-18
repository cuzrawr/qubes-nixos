#!/usr/bin/env python3
"""run in dom0 on a disposable test TemplateVM. grows root by 2 GiB total."""

import hashlib
import shlex
import subprocess
import sys
import time
import uuid

import qubesadmin


if len(sys.argv) != 2:
    sys.exit("usage: lab-resize.py STOPPED_TEST_TEMPLATE")
vm = qubesadmin.Qubes().domains[sys.argv[1]]
assert vm.klass == "TemplateVM", "use a dedicated test TemplateVM"
assert not vm.is_running(), "shut down the test template before this test"
assert vm.qrexec_timeout == 60, "use the normal 60-second qrexec timeout"


def run(command, user="root"):
    return vm.run(command, user=user)[0].decode().strip()


def boot():
    start = time.monotonic()
    subprocess.run(["qvm-start", vm.name], check=True)
    print(f"START seconds={time.monotonic() - start:.2f}", flush=True)
    assert run("systemctl is-system-running --wait") == "running"
    run("for i in $(seq 1 30); do test ! -S /run/user/1000/bus || break; sleep 1; done; test -S /run/user/1000/bus")


def shutdown():
    subprocess.run(["qvm-shutdown", "--wait", vm.name], check=True)


def filesystem_bytes():
    block_size, blocks = map(int, run("stat -f -c '%S %b' /").split())
    return block_size * blocks


def grow():
    target = vm.volumes["root"].size + 1024**3
    subprocess.run(["qvm-volume", "extend", vm.name + ":root", str(target)], check=True)


def check(previous_size):
    size = filesystem_bytes()
    assert size > previous_size, "root volume grew but its filesystem did not"
    assert run("sha256sum " + marker).split()[0] == checksum, "root file changed"
    for user in ("root", "user"):
        scope = "--user" if user == "user" else ""
        failed = run(
            f"XDG_RUNTIME_DIR=/run/user/1000 systemctl {scope} --failed --no-legend --plain",
            user=user,
        )
        assert not failed, f"failed {user} units: {failed}"
    print(f"RESIZE_PASS filesystem_bytes={size}", flush=True)
    return size


boot()
marker = shlex.quote(run("mktemp /root/qubes-nixos-resize.XXXXXX"))
data = uuid.uuid4().hex
checksum = hashlib.sha256(data.encode()).hexdigest()
run("printf %s " + shlex.quote(data) + " > " + marker)
size = filesystem_bytes()
shutdown()
grow()
boot()
size = check(size)
grow()
check(size)
run("rm -- " + marker)
shutdown()
print("RESIZE_PASS cold boot, live growth, file integrity, system/user units")
