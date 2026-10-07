# Recovery and integration updates

Applies to both templates and their stock external-kernel boot path.

## Restore a generation

Inside a bootable TemplateVM:

```sh
sudo nixos-rebuild switch --rollback --no-reexec
sudo poweroff
```

Restart dependent AppVMs. Restore edited Nix files separately. Use Qubes backup
restore for application data; Nix rollback does not roll back home directories.

## Rebuild from GitHub

On an x86_64 Linux builder with Nix and Git:

```sh
git clone https://github.com/cuzrawr/qubes-nixos qubes-nixos-recovery
cd qubes-nixos-recovery
git switch --detach v0.1.0

# Stable
nix build .#template-rpm -o result-stable

# Unstable, if required
nix build .#template-rpm-unstable -o result-unstable
```

Use the tag or source commit from the matching [test/release record](testing.md).
Keep `flake.lock`; do not update inputs while reproducing that version.
[Sign the RPM](distribution.md#sign-a-local-build), then transfer it and the
public key to dom0 using the README commands.

## Replace root without deleting AppVMs

1. Back up the TemplateVM and dependent AppVMs with Qubes Backup.
2. Save custom `/etc/nixos` changes outside the template.
3. Shut down the template and all its dependent qubes.
4. In dom0, reinstall from the configured repository:

```sh
qvm-template --repoid=qubes-nixos --refresh reinstall nixos-26.05-xfce
# Or: qvm-template --repoid=qubes-nixos --refresh reinstall nixos-unstable-xfce
```

Alternatively, use the matching downloaded or locally built signed RPM:

```sh
qvm-template --keyring ./template-key.asc reinstall ./TEMPLATE.rpm
```

5. Start the template; check guest services; shut it down.
6. Restart one AppVM and check it before restarting the others.

Reinstallation replaces root, including `/etc/nixos` and root-installed software.
It does not reset existing AppVM private data. Reapply reviewed custom settings
after confirming the base template works.

## Complete delete/install cycle

Use this when replacement through `reinstall` is unsuitable. Keep AppVMs halted
while temporarily assigning their template property elsewhere.

```sh
# dom0: choose either nixos-26.05-xfce or nixos-unstable-xfce
template=nixos-26.05-xfce
qvm-shutdown --wait MY_APP
qvm-shutdown --wait "$template"
qvm-prefs MY_APP template EXISTING_FALLBACK_TEMPLATE
# Repeat the reassignment for every dependent AppVM/disposable template.
qvm-template remove "$template"
qvm-template --keyring ./template-key.asc install ./TEMPLATE.rpm
qvm-prefs MY_APP template "$template"
qvm-start MY_APP
```

- Keep AppVMs halted until reassigned to the restored NixOS template.
- Repeat for all dependencies, including disposable templates and global
  defaults that referred to the removed template.
- Use `remove`, not `purge`, to preserve dependent data.
- Removing and installing anew also resets the TemplateVM's private data;
  restore required data from backup.
- A native Qubes backup can restore the old TemplateVM directly instead of
  rebuilding. Use Backup Restore or `qvm-backup-restore` in dom0.

## Update the integration source

`nix flake update` refreshes nixpkgs; it does not update this repository's modules,
Qubes component pins or packaging.

1. Back up `/etc/nixos` and record the current generation.
2. Obtain the intended GitHub source commit on a builder or in a temporary clone.
3. Review/merge integration changes into `/etc/nixos`; retain your software list,
   local modules, update target and original `system.stateVersion`.
4. Review `flake.lock` and `pkgs/sources.nix` together with the release notes.
5. Run `nix flake check`, then the matching `nixos-rebuild switch --flake` command.
6. Check system and user units; shut down the template; test one restarted AppVM.

For configurations managed in Git, merge the selected upstream commit normally.
The shipped `/etc/nixos` copy has no `.git` directory; do not assume `git pull`
works there. Avoid copying a new default `configuration.nix` over your changes.

For a major NixOS release, build a separately named template, test it, then
reassign AppVMs. Keep the old template until the replacement and backups work.
