#!/usr/bin/env python3
"""Run in dom0 against a dedicated test AppVM; restore its firewall afterward."""
import subprocess
import sys
import time

import qubesadmin
import qubesadmin.firewall


vm = qubesadmin.Qubes().domains[sys.argv[1]]
command = "curl --connect-timeout 5 --max-time 15 -fsS https://cache.nixos.org/nix-cache-info"
original = list(vm.firewall.rules)


def fetch():
    return vm.run(command, user="user")[0]


def handled():
    output, _ = vm.netvm.run_with_args(
        "qubesdb-read", f"/qubes-firewall-handled/{vm.ip}", user="root"
    )
    return int(output)


def set_rules(rules):
    previous = handled()
    vm.firewall.rules = rules
    deadline = time.monotonic() + 15
    while handled() <= previous:
        if time.monotonic() > deadline:
            raise AssertionError("NetVM did not acknowledge the firewall change")
        time.sleep(0.2)


assert b"StoreDir: /nix/store" in fetch(), "Initial HTTPS request failed"
try:
    set_rules([qubesadmin.firewall.Rule("action=drop")])
    try:
        fetch()
    except subprocess.CalledProcessError:
        pass
    else:
        raise AssertionError("HTTPS succeeded with the qube's firewall set to drop")
finally:
    set_rules(original)

assert b"StoreDir: /nix/store" in fetch(), "HTTPS did not recover after restoring rules"
print(f"NETWORK_PASS {vm.name}: DNS, HTTPS, native firewall deny and recovery")
