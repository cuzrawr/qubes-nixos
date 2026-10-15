# Recovery and integration updates

Applies to stable/unstable, XFCE/minimal and the stock external-kernel boot path.
Commands inside a guest require root. Minimal: open a root terminal from dom0
with `qvm-run -u root TEMPLATE xterm`; omit `sudo` inside that terminal.

## 0.1.0 to 0.1.1

Status: release tests in progress. Do not treat this section as an announcement
that 0.1.1 binaries are published. [Acceptance record](testing.md).

| Change | Effect on existing users |
| --- | --- |
| RPM release `1` to `2` | Qubes Template Manager can distinguish the replacement build |
| Resize service ordering | Fixes the reproduced networked root-growth boot cycle; no partition conversion |
| Shared GUI/audio modules | XFCE selections remain; minimal is a separate template choice |
| `profiles/base.nix` | Shared Nix/documentation/state-version defaults moved out of the full application selection |
| New minimal templates | Separate names; an XFCE upgrade does not silently become minimal |

### Packaged template replacement

1. Back up the TemplateVM and AppVMs with Qubes Backup.
2. Save customized `/etc/nixos` outside the template. A template RPM upgrade
   replaces this directory and the rest of its root.
3. Shut down dependent qubes, then the TemplateVM.
4. After 0.1.1 is published, select the update in Template Manager, or use
   `qvm-template --repoid=qubes-nixos --refresh upgrade TEMPLATE` in dom0.
5. Start the template; check `systemctl --failed` and `df -h /`; shut it down.
6. Test one AppVM. Its private data should remain; verify before starting others.
7. Reapply reviewed local options to the new configuration and rebuild.

Do not copy the old `modules/` tree over the replacement: that restores the old
integration. Keep the backup until the new template and applications work.

### Keep a customized source configuration

Use [integration source updates](#update-the-integration-source), without
replacing the template RPM. Review these 0.1.1 changes together:

- `flake.nix`, `profiles/base.nix`, `modules/` and the profile selection file.
- Preserve local packages, imported modules, update target/input and
  `system.stateVersion`.
- Existing custom settings can remain in `configuration.nix`; shared scalar
  defaults use `mkDefault` so ordinary local values can override them.
- Keep `boot.kernel.enable` and `boot.initrd.enable` false. Keep the new resize
  unit ordering from [configuration](configuration.md#boot-and-service-ordering).
- Build first with `nixos-rebuild build --flake /etc/nixos#CONFIGURATION`.
  Apply with `switch` only after a successful build. Check failed units and
  restart the template before testing its AppVMs.

For a 0.1.0 template that cannot start after growth, use the
[resize recovery procedure](resizing.md#startup-timeout-on-010) first.

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
The 0.1.0 tag contains XFCE only. Minimal build targets first appear in 0.1.1;
use their matching tag and the build-output table in the README.
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

## Install a newer template RPM

Follow the same backup and shutdown steps above. When a newer RPM is published,
select it in Qubes Template Manager, or run in dom0:

```sh
qvm-template --repoid=qubes-nixos --refresh upgrade nixos-26.05-xfce
# Or: qvm-template --repoid=qubes-nixos --refresh upgrade nixos-unstable-xfce
```

This replaces template root, including custom `/etc/nixos` changes. Existing
AppVM private data remains. Use the README's in-template NixOS update procedure
to retain and rebuild your configuration instead. A smaller replacement image
does not remove retained Qubes volume revisions.

Source: [native template commands](https://doc.qubes-os.org/projects/core-admin-client/en/latest/manpages/qvm-template.html).

## Complete delete/install cycle

Use this when replacement through `reinstall` is unsuitable. Keep AppVMs halted
while temporarily assigning their template property elsewhere.

```sh
# dom0: choose the installed template name from the README table
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
