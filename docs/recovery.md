# Recovery and integration updates

Applies to stable/unstable, XFCE/minimal and the stock external-kernel boot path.
Commands inside a guest require root. Minimal: open a root terminal from dom0
with `qvm-run -u root TEMPLATE xterm`; omit `sudo` inside that terminal.

## 0.1.0 to 0.1.1

0.1.1 is not released. Final RPM upgrade acceptance is still UNVERIFIED.
Use these steps after publication. [Test coverage](testing.md),
[release changes](../versions.txt).

### Choose the upgrade method

| Method | What happens |
| --- | --- |
| Template Manager or signed RPM | Replaces root and clears the TemplateVM's own private volume |
| [Update integration source](#keep-a-customized-source-configuration) | Keeps reviewed local configuration; builds and activates a new NixOS generation |
| Ordinary `nix flake update` | Updates package pins only; does not install this integration upgrade |

RPM upgrade/reinstall removes the TemplateVM's custom `/etc/nixos`, software,
generations, home files, `/usr/local` and other private-volume contents.
Existing AppVM private volumes remain separate. This is the native Qubes 4.3
[replacement behavior][postprocess], confirmed in the installed tool's source.
Confidence: high. Back up the template and AppVMs before proceeding.
[Qubes persistence][persistence].

The XFCE template names stay the same. Minimal templates are separate choices;
this upgrade does not convert an XFCE template to minimal. RPM release changes
from `4.3.0-1` to `4.3.0-2`.

### 1. Identify the template and its qubes

Open Qubes Manager. Sort by the Template column and note every qube using the
one being upgraded, including disposable templates.

| Installed template | Matching 0.1.1 replacement |
| --- | --- |
| `nixos-26.05-xfce` | `nixos-26.05-xfce` |
| `nixos-unstable-xfce` | `nixos-unstable-xfce` |

In commands below, `TEMPLATE` means that exact installed name. `APP` means one
of its AppVMs. Upgrade one template at a time.

Record any custom template settings in Qubes Settings, especially networking.
Native post-install processing resets the template's NetVM to its default.

For service qubes providing networking or input, arrange another provider before
shutting them down. The backup destination and UpdateVM must remain usable.

### 2. Save custom configuration and back up

If `/etc/nixos` was customized, open a terminal in the TemplateVM and run:

```sh
umask 077
archive="$HOME/nixos-before-0.1.1-$(date +%Y%m%d-%H%M%S).tar.gz"
sudo tar -C /etc -czf - nixos > "$archive"
tar -tzf "$archive"
qvm-copy "$archive"
```

Choose a separate qube in the copy dialog. Check that the archive arrived and
lists your files before continuing. Save any local files imported from outside
`/etc/nixos` and needed template home or `/usr/local` files too. The archive must
leave the TemplateVM: its home directory is cleared during RPM replacement.

1. Save work and shut down the template's AppVMs, disposables and TemplateVM.
2. Open **Backup Qubes** from the application menu. Move the TemplateVM and all
   its persistent dependent qubes into **Selected**. Do not assume they are
   selected automatically.
3. Choose a destination outside these qubes, preferably an external backup
   device. Keep the passphrase separately. Check the summary includes every
   intended qube, then complete the backup.
4. Open **Restore Backup**, select that archive and its passphrase, and choose
   the option to verify integrity without restoring data. Select the backed-up
   qubes and finish verification. Stop if backup or verification reports an error.

Integrity verification checks archive corruption; it does not prove that omitted
files were backed up. Keep the archive until the replacement and applications
have been checked. [Official backup/restore procedure][backup].

### 3. Upgrade through Template Manager

1. Check the Qubes storage pool has room for the download and import.
2. Open **Qubes Template Manager** (`qvm-template-gui` in dom0).
3. Refresh repository data. Under **Installed templates**, select the same
   template name and choose **Upgrade**. Confirm the replacement is release `2`.
4. Read the replacement warning, then start the upgrade. Wait for successful
   completion; do not shut down the computer during import.

If no upgrade is offered, check that 0.1.1 is published and the
[project repository is configured](../README.md#fast-template-launch-procedure).
Do not remove the old template to force an upgrade.

Equivalent command in dom0, after replacing `TEMPLATE`:

```sh
qvm-template --repoid=qubes-nixos --refresh upgrade TEMPLATE
```

For a local RPM, transfer the matching signed file and verified public key as
shown in the [README](../README.md#install-a-signed-rpm), then use **upgrade**:

```sh
# stable; use the unstable filename for an unstable template
rpm=qubes-template-nixos-26.05-xfce-4.3.0-2.noarch.rpm
qvm-template --keyring ./template-key.asc upgrade "./$rpm"
```

The unstable filename is
`qubes-template-nixos-unstable-xfce-4.3.0-2.noarch.rpm`.
Both methods replace root and clear the TemplateVM's private volume.
[Native template commands][template-cli].

### 4. Check before resuming work

1. Review the template's Qubes Settings against the recorded settings. Restore
   any intentional networking selection, then start a terminal in the template:

```sh
systemctl --failed
systemctl --user --failed
df -h /
```

2. Both unit lists must report zero failed units. Check root has free space.
   A completed import or release `2` in Template Manager alone is not a boot test.
3. Reapply reviewed local packages/options from the saved configuration and
   rebuild using the matching [README command](../README.md#2-use-and-change-software).
   Check failed units again. Do not overwrite the new `modules/` with the old copy.
   Restore any needed template home or `/usr/local` files from the external copy.
4. Shut down the TemplateVM. Start one AppVM. Check important files, application
   settings, required software and network access before starting the others.
5. Keep the backup until all dependent qubes have been checked.

### If something fails

- Stop. Keep the other dependent qubes shut down and retain the error output.
- Failed download/signature check: fix that error before retrying; do not disable
  signature checking.
- Failed NixOS rebuild: use [generation rollback](#restore-a-generation).
- Broken template after RPM replacement: restore the old TemplateVM from the
  Qubes backup under a different name. Review the restore summary before
  confirming. Keep the replacement until the restored template boots.
- While an AppVM is halted, select the restored template in its Qubes Settings.
  Test that AppVM before switching the others. Do not delete or recreate AppVMs.

If a name conflict blocks restore, the native CLI can restore only the selected
TemplateVM under another name. In dom0, substitute the backup qube, archive path
inside that qube and original template name:

```sh
qvm-backup-restore --dest-vm BACKUP_QUBE --rename-conflicting /path/to/BACKUP TEMPLATE
```

Read the restore summary for the new name. This restores the selected template,
not its AppVMs. Restore AppVM data separately only if required; use a different
name to inspect recovered files before replacing current data.
[Restore options][restore-cli].

NixOS rollback cannot recover generations removed by RPM replacement. For a
0.1.0 template stuck after disk growth, try the
[resize recovery procedure](resizing.md#startup-timeout-on-010) before replacement.

### Keep a customized source configuration

Use [integration source updates](#update-the-integration-source) instead of RPM
replacement. Tested on both XFCE pins with a custom package and scalar setting;
this does not cover every local configuration. Confidence: high for those tests.

- Review `flake.nix`, `profiles/base.nix`, `modules/` and the profile selection
  together. Keep local packages, imported modules, update target/input and
  `system.stateVersion`.
- Existing custom settings can stay in `configuration.nix`; shared scalar
  defaults use `mkDefault` so ordinary local values can override them.
- Keep `boot.kernel.enable` and `boot.initrd.enable` false. Preserve the
  [resize unit ordering](configuration.md#boot-and-service-ordering).
- Build with `nixos-rebuild build --flake /etc/nixos#CONFIGURATION` before
  `switch`. Check failed units and reboot the template before testing an AppVM.

[backup]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-back-up-restore-and-migrate.html
[persistence]: https://doc.qubes-os.org/en/r4.3/user/templates/templates.html#inheritance-and-persistence
[template-cli]: https://doc.qubes-os.org/projects/core-admin-client/en/latest/manpages/qvm-template.html
[restore-cli]: https://doc.qubes-os.org/projects/core-admin-client/en/latest/manpages/qvm-backup-restore.html
[postprocess]: https://github.com/QubesOS/qubes-core-admin-client/blob/release4.3/qubesadmin/tools/qvm_template_postprocess.py

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
2. Copy custom `/etc/nixos` and needed template home or `/usr/local` files to
   another qube, as in the [backup steps](#2-save-custom-configuration-and-back-up).
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

Reinstallation replaces template root and clears its private volume, including
its home and `/usr/local`. Existing AppVM private data stays separate. Reapply
reviewed settings and restore needed template files after checking its boot.

## Install a newer template RPM

Follow the same backup and shutdown steps above. When a newer RPM is published,
select it in Qubes Template Manager, or run in dom0:

```sh
qvm-template --repoid=qubes-nixos --refresh upgrade nixos-26.05-xfce
# Or: qvm-template --repoid=qubes-nixos --refresh upgrade nixos-unstable-xfce
```

This replaces template root and clears its private volume. Existing AppVM
private data stays separate. Use the README's in-template NixOS update procedure
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
