# Recovery and integration updates

- Applies to stable/unstable, XFCE/minimal and the stock external-kernel boot path.
- Rebuild and maintenance commands require root; status checks do not.
- Minimal: run `qvm-run -u root TEMPLATE xterm` in dom0. Omit `sudo` in that terminal.

## 0.1.0 to 0.1.1

**Not released. Final RPM upgrade acceptance: UNVERIFIED.**

Use these steps after publication.
[Test coverage](testing.md) | [Release changes](../versions.txt).

### Choose the upgrade method

| Method | What happens |
| --- | --- |
| Template Manager or signed RPM | Replaces root and clears the TemplateVM's own private volume |
| [Update integration source](#keep-a-customized-source-configuration) | Keeps reviewed local configuration; builds and activates a new NixOS generation |
| Ordinary `nix flake update` | Updates package pins only; does not install this integration upgrade |

**Back up the template and AppVMs first.**

RPM upgrade/reinstall removes:

- Template root: custom `/etc/nixos`, software and generations.
- Template private data: home files, `/usr/local` and other private contents.

Existing AppVM private volumes remain separate. This is native Qubes 4.3
[replacement behavior][postprocess], confirmed in the installed tool's source.
Confidence: high. [Qubes persistence][persistence].

XFCE template names stay the same. Minimal templates are separate choices;
an XFCE upgrade does not select minimal. Expected replacement RPM: `4.3.0-2`.

### 1. Identify the template and its qubes

In Qubes Manager:

1. Sort by the Template column.
2. Note every qube using the template, including disposable templates.
3. Record custom template settings, especially networking.

| Installed template | Matching 0.1.1 replacement |
| --- | --- |
| `nixos-26.05-xfce` | `nixos-26.05-xfce` |
| `nixos-unstable-xfce` | `nixos-unstable-xfce` |

- `TEMPLATE`: the exact installed template name.
- `APP`: one of its AppVMs.
- Upgrade one template at a time.

**Settings:** native post-install processing resets the template's NetVM to its
default.

**Service qubes:** arrange another network/input provider before shutting them
down. Keep the backup destination and UpdateVM usable.

### 2. Save custom configuration and back up

If you customized `/etc/nixos`, run in the TemplateVM:

```sh
umask 077
archive="$HOME/nixos-before-0.1.1-$(date +%Y%m%d-%H%M%S).tar.gz"
sudo tar -C /etc -czf - nixos > "$archive"
tar -tzf "$archive"
qvm-copy "$archive"
```

- Choose a separate qube in the copy dialog.
- Check that the archive arrived and lists your files.
- Also save imported files outside `/etc/nixos` and needed template home or
  `/usr/local` files.

**The archive must leave the TemplateVM.** RPM replacement clears its home.

Then make a full Qubes backup:

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

**Verification:** checks archive integrity, not whether you selected every
needed file/qube. Keep the backup until the replacement and applications work.
[Official backup/restore procedure][backup].

### 3. Upgrade through Template Manager

1. Check the Qubes storage pool has room for the download and import.
2. Open **Qubes Template Manager** (`qvm-template-gui` in dom0).
3. Refresh repository data. Under **Installed templates**, select the same
   template name and choose **Upgrade**. Confirm the replacement is release `2`.
4. Read the replacement warning, then start the upgrade. Wait for successful
   completion; do not shut down the computer during import.

**No upgrade offered:** check publication and
[repository setup](../README.md#fast-template-launch-procedure).
Do not delete the old template to force an upgrade.

Equivalent command in dom0, after replacing `TEMPLATE`:

```sh
qvm-template --repoid=qubes-nixos --refresh upgrade TEMPLATE
```

For a local RPM:

1. Transfer the matching signed file and verified public key using the
   [README procedure](../README.md#install-a-signed-rpm).
2. Run **upgrade** in dom0:

```sh
# stable; use the unstable filename for an unstable template
rpm=qubes-template-nixos-26.05-xfce-4.3.0-2.noarch.rpm
qvm-template --keyring ./template-key.asc upgrade "./$rpm"
```

Unstable filename: `qubes-template-nixos-unstable-xfce-4.3.0-2.noarch.rpm`.

**Both methods replace root and clear the TemplateVM's private volume.**
[Native template commands][template-cli].

### 4. Check before resuming work

1. Review the template's Qubes Settings against the recorded settings. Restore
   any intentional networking selection, then open a normal user terminal in
   the template. `systemctl --user` must check the desktop user's services:

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

If a name conflict blocks restore, use the native CLI in dom0:

- `BACKUP_QUBE`: qube holding the backup.
- `/path/to/BACKUP`: archive path inside that qube.
- `TEMPLATE`: original template name.

```sh
qvm-backup-restore --dest-vm BACKUP_QUBE --rename-conflicting /path/to/BACKUP TEMPLATE
```

- Read the restore summary for the new template name.
- This restores only the selected TemplateVM.
- Restore AppVM data separately only if needed. Use another name to inspect
  recovered files before replacing current data.

[Restore options][restore-cli].

**NixOS rollback cannot recover generations removed by RPM replacement.**

For a 0.1.0 template stuck after disk growth, try
[resize recovery](resizing.md#startup-timeout-on-010) before replacement.

### Keep a customized source configuration

Use [integration source updates](#update-the-integration-source) to retain local
configuration.

Coverage: both XFCE pins, with a custom package and scalar setting.
Confidence: high for those tests; other custom configurations need testing.

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

- Restart dependent AppVMs.
- Restore edited Nix files separately.
- Use Qubes backup restore for application data. Nix rollback does not restore
  home directories.

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

- Select the tag or source commit from the matching [test record](testing.md).
- The example tag contains XFCE only. For minimal, use its published tag and
  the build-output table in the README.
- Keep `flake.lock`. Do not update inputs while reproducing that version.
- [Sign the RPM](distribution.md#sign-a-local-build), then transfer it and the
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

**Reinstallation replaces root and clears the template's private volume,**
including home and `/usr/local`. Existing AppVM private data stays separate.

Check the template boots before reapplying reviewed settings and restoring its
needed files.

## Install a newer template RPM

Follow the same backup and shutdown steps above. When a newer RPM is published,
select it in Qubes Template Manager, or run in dom0:

```sh
qvm-template --repoid=qubes-nixos --refresh upgrade nixos-26.05-xfce
# Or: qvm-template --repoid=qubes-nixos --refresh upgrade nixos-unstable-xfce
```

- Replaces template root and clears its private volume.
- Existing AppVM private data stays separate.
- To retain your configuration, use the README's in-template NixOS update
  procedure instead.
- A smaller replacement image does not remove retained Qubes volume revisions.

Source: [native template commands](https://doc.qubes-os.org/projects/core-admin-client/en/latest/manpages/qvm-template.html).

## Complete delete/install cycle

Use this when `reinstall` is unsuitable.

**Complete the [backup steps](#2-save-custom-configuration-and-back-up) first.**
Keep AppVMs halted while temporarily assigning them to another template.

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

`nix flake update` refreshes the flake inputs. It does not update this repository's
modules, Qubes component pins or packaging.

1. Back up `/etc/nixos` and record the current generation.
2. Obtain the intended GitHub source commit on a builder or in a temporary clone.
3. Review/merge integration changes into `/etc/nixos`; retain your software list,
   local modules, update target and original `system.stateVersion`.
4. Review `flake.lock` and `pkgs/sources.nix` together with the release notes.
5. Run `nix flake check`, then the matching `nixos-rebuild switch --flake` command.
6. Check system and user units; shut down the template; test one restarted AppVM.

- Already managed in Git: merge the selected upstream commit normally.
- Shipped `/etc/nixos`: no `.git` directory, so `git pull` does not work there.
- Do not overwrite local changes with a new default `configuration.nix`.

For a major NixOS release:

1. Build a separately named template.
2. Test it before reassigning AppVMs.
3. Keep the old template until the replacement and backups work.
