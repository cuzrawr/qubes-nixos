# Recovery

| Profile | Template name |
| --- | --- |
| Stable XFCE | `nixos-26.05-xfce` |
| Unstable XFCE | `nixos-unstable-xfce` |
| Stable minimal | `nixos-26.05-minimal` |
| Unstable minimal | `nixos-unstable-minimal` |

Command examples use **stable XFCE only**. Use the matching template and flake
configuration from the [profile table](../README.md#versions) for another profile.
Minimal administration uses a root terminal opened from dom0; omit `sudo` there.

Routine updates: [updates](updates.md).
To open a normal template terminal, run in **dom0**:

```sh
qvm-run nixos-26.05-xfce xfce4-terminal
```
Before replacing files or a template: [save configuration and verify a backup](updates.md#before-changing-a-template).

[Recorded test coverage](testing.md). Confidence: high for the recorded tests;
other recovery cases require verification.

## Choose the recovery path

| Symptom | Start here |
| --- | --- |
| Download, evaluation or build failed before activation | [Failed package update](#failed-package-update) |
| Activation failed, or updated software/services are broken | [Restore a generation](#restore-a-generation) |
| Rollback works, but the next rebuild repeats the failure | [Restore the lock file or source](#restore-the-lock-file-or-source) |
| Template does not start, or root qrexec is unavailable | [Template will not boot](#template-will-not-boot) |
| Needed files disappeared after RPM replacement | [Restore a Qubes backup](#restore-a-qubes-backup) |
| No usable generation or backup; replace the template | [Reinstall as a last resort](#reinstall-as-a-last-resort) |

**Save work before stopping qubes.** Stopping discards unsaved work and disposable
contents. Keep dependent AppVMs stopped while repairing their template. Do not delete
AppVMs, run garbage collection or remove generations during recovery.
Stop if a repair/build command fails; save its output before trying another
procedure. Diagnostic `systemctl status` returns a nonzero status for a failed
or inactive service; use its output to identify the problem.

## Failed package update

Run in a **normal terminal inside `nixos-26.05-xfce`**:

```sh
sudo systemctl status qubes-nixos-update --no-pager
sudo journalctl -b -u qubes-nixos-update --no-pager
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
df -h / /rw
```

- A failed download, evaluation or build does not activate the candidate.
- The updater may already have changed `/etc/nixos/flake.lock`.
- Notification failure can occur after a successful activation. Check the latest
  journal entries and system paths before deciding whether rollback is needed.
- A failed activation can leave some services/configuration changed. Do not
  assume the old system is intact because the command returned an error.
- Compare the system paths with your pre-update record. If activation started
  or the paths differ unexpectedly, use [generation rollback](#restore-a-generation).

Fix the reported cause: configuration error, unavailable download, update-proxy
failure or [insufficient disk space](resizing.md). Do not disable signature
checks or delete the Nix store to make a retry succeed.

To retry an unchanged lock file, use the build/switch procedure in
[updates](updates.md). Starting the update service again refreshes package pins
and saves another lock-file backup.

## Restore a generation

Use this when the TemplateVM still accepts commands and a working generation
is retained. **This does not restore edited Nix files or application data.**

Run in a **normal terminal inside `nixos-26.05-xfce`**:

```sh
sudo nix-env -p /nix/var/nix/profiles/system --list-generations
sudo nixos-rebuild switch --rollback --no-reexec
```

- The command selects the previous retained system generation.
- `--no-reexec` avoids evaluating a broken flake to update `nixos-rebuild` first.
- Do not repeat rollback blindly: the previous generation must be one you
  expect to work. If it is unavailable, use a Qubes backup.
- `/etc/nixos`, its `flake.lock`, `/home` and application databases stay as they
  are. Older software may not understand data migrated by newer software.
- Generations removed by garbage collection or RPM replacement cannot be
  recovered this way. These templates have no GRUB generation menu.

Repair the source separately before the next rebuild. Then use
[check recovery](#check-recovery) below.
[NixOS rollback reference][nixos-rollback].

## Restore the lock file or source

### Only the package pins are wrong

The update service saves the previous lock file at
`/var/lib/qubes/flake.lock.previous`. Repeated runs retain numbered older copies.
A manually run `nix flake update` does not create this project backup.

Run in a **normal terminal inside `nixos-26.05-xfce`**:

```sh
sudo ls -lt /var/lib/qubes/flake.lock.previous*
sudo cat /var/lib/qubes/flake.lock.previous
```

Choose the backup from before the failing update. The following example uses
`flake.lock.previous`; substitute the numbered filename if necessary.

```sh
sudo cp --backup=numbered /etc/nixos/flake.lock /etc/nixos/flake.lock.before-recovery &&
  sudo install -m 0644 /var/lib/qubes/flake.lock.previous /etc/nixos/flake.lock &&
  sudo nixos-rebuild build --flake /etc/nixos#nixos --no-update-lock-file
```

**Stop if the build fails.** Restoring a lock file changes future builds, not
the running system. When the build succeeds:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#nixos --no-update-lock-file
```

If local Nix files changed too, restore the matching source backup below.
Starting the updater now would refresh the pins again.

### Configuration files are wrong or missing

1. Copy your saved configuration archive back from the backup qube using
   Qubes file copy. Put it in the template's home as `nixos-config-backup.tar.gz`.
2. Use only your own trusted archive. Extract it into an empty directory,
   without root privileges. These commands run in a **normal terminal inside
   `nixos-26.05-xfce`**:

```sh
mkdir -m 700 "$HOME/nixos-recovery" &&
  tar -tf "$HOME/nixos-config-backup.tar.gz" &&
  tar --no-same-owner --no-same-permissions -xf "$HOME/nixos-config-backup.tar.gz" -C "$HOME/nixos-recovery"
```

3. Check that `nixos-recovery/nixos/` contains your `flake.nix`, `flake.lock`,
   configuration and imported modules. Restore separately backed-up imports
   outside that directory to their expected locations too.
4. Stage the recovered source and build it before replacing `/etc/nixos`:

```sh
test ! -e /etc/nixos.recovered && test ! -L /etc/nixos.recovered &&
  sudo cp -a "$HOME/nixos-recovery/nixos" /etc/nixos.recovered &&
  sudo chown -R root:root /etc/nixos.recovered &&
  sudo nixos-rebuild build --flake /etc/nixos.recovered#nixos --no-update-lock-file
```

5. **Stop if staging or build fails.** If either saved directory below already
   exists, keep it and choose another unused name before continuing.
   Preserve the current source, then select the recovered copy:

```sh
test ! -e /etc/nixos.before-recovery && test ! -L /etc/nixos.before-recovery &&
  sudo mv /etc/nixos /etc/nixos.before-recovery &&
  sudo mv /etc/nixos.recovered /etc/nixos
```

6. If `/etc/nixos` was missing, skip its rename and move only
   `/etc/nixos.recovered` to `/etc/nixos`. If the second rename fails, move
   `/etc/nixos.before-recovery` back before continuing. Once the recovered
   source is in place, activate it:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#nixos --no-update-lock-file
```

**This restores the whole saved source, including its integration version.**
Do not mix old `modules/` with a new `flake.nix`. Keep the saved current source
until recovery is checked. An archive made before later package additions
will not include those additions.

## Template will not boot

1. Keep dependent AppVMs stopped. Save the startup error and available qube
   logs in Qubes Manager.
2. Check free space in Qubes' disk-space widget. Check the template's kernel
   and virtualization settings against the [supported configuration](configuration.md#boot-and-service-ordering).
3. If startup failed after increasing root storage, try the
   [resize-timeout recovery](resizing.md#startup-timeout-on-010).
4. If only desktop startup failed, try this read-only command in **dom0**:

```sh
qvm-run -p --no-gui -u root nixos-26.05-xfce 'systemctl --failed; journalctl -b -p err --no-pager'
```

5. If root qrexec works, open an administrator terminal from **dom0**:

```sh
qvm-run -u root nixos-26.05-xfce xterm
```

Run generation rollback there without `sudo`. If qrexec works but Xorg cannot open a terminal, run the rollback in **dom0**:

```sh
qvm-run -p --no-gui -u root nixos-26.05-xfce 'nixos-rebuild switch --rollback --no-reexec'
```

If qrexec is unavailable, restore a backup below. Keep the broken template for inspection; do not format
its volumes or attempt a generic NixOS GRUB recovery.

## Restore a Qubes backup

**Keep the broken template. Restore a separate copy first.**

1. Open **Restore Backup** from the Qubes application menu. Choose the backup
   location and passphrase, then verify integrity without restoring data.
   Stop if verification fails.
2. Ensure the backup contains `nixos-26.05-xfce`. Keep the existing template
   with that name so native conflict renaming creates a separate copy.
3. In **dom0**, replace `BACKUP_QUBE` and `/path/to/qubes-backup` with the qube
   holding the archive and its path inside that qube:

```sh
qvm-backup-restore --dest-vm BACKUP_QUBE --rename-conflicting /path/to/qubes-backup nixos-26.05-xfce
```

4. Review the restore summary before confirming. Record the new template name.
   This command selects only the TemplateVM; it does not replace AppVM data.
5. In Qubes Manager, review the restored template's settings, start it and
   [check its services](#check-recovery). Shut it down afterward.
6. Select one halted AppVM, open **Settings**, and choose the restored
   template. Start it; check files, applications and networking before moving
   the remaining AppVMs.

**Application data recovery:** restore the affected AppVM under another name
and inspect its files separately. A TemplateVM restore does not undo changes
to an AppVM's private volume. Copying recovered files over current files can
overwrite newer work; keep both copies until you have compared them. Keep current AppVMs and the backup until checked.
[Official backup procedure][backup] | [Restore command][restore-cli].

## Reinstall as a last resort

Use this when no retained generation or usable backup can repair the template.
Finish the [backup steps](updates.md#before-changing-a-template), including any
files still recoverable. Shut down the template and all dependent qubes.

**Reinstall removes the TemplateVM's custom root and clears its private
volume: `/etc/nixos`, software, generations, home files and `/usr/local`.**
Existing AppVM private volumes are separate. A NixOS rollback cannot undo this.
Files already erased by replacement cannot be recovered from a fresh image;
you need a backup of those files.
Native post-install also resets the template's NetVM to its default.
Confidence: high; verified in [Qubes post-install source][postprocess].

Run in **dom0**, with the repository already configured:

```sh
qvm-template --repoid=qubes-nixos --refresh reinstall nixos-26.05-xfce
```

`reinstall` requires the same RPM version/release as currently installed.
If it is unavailable, stop and obtain that signed RPM; do not force an upgrade
as a recovery shortcut.

For a local signed RPM, use the [transfer and signature procedure](../README.md#install-a-signed-rpm)
first. For an installed `4.3.0-2` stable XFCE image, run **in dom0**:

```sh
qvm-template --keyring ./template-key.asc reinstall ./qubes-template-nixos-26.05-xfce-4.3.0-2.noarch.rpm
```

For an installed `4.3.0-1` image, obtain and use its matching signed RPM from
`v0.1.0` instead. Do not substitute a newer image in a reinstall command.

**The local command has the same data loss as repository reinstall.**
Review settings, check boot, and restore needed files from backup. Reapply
reviewed custom packages/options; do not blindly copy old integration modules
over the replacement. [Native template commands][template-cli].

### Complete delete/install cycle

**Deleting the template removes all its root and private data.** Do not do this
if a backup restore or reinstall is sufficient. Keep AppVMs; do not use `purge`.

1. Verify a full backup and save recoverable configuration outside the template.
2. Obtain and verify the intended signed RPM before deleting anything.
3. In Qubes Manager, sort by **Template**. Shut down every dependent qube,
   including disposable templates. Arrange alternate service qubes first if
   these provide networking or input.
4. In each halted dependent qube's **Settings**, temporarily select another
   installed template. Keep these qubes stopped. Record defaults referring to
   the old template and change them temporarily in Qubes Global Settings.
5. Shut down `nixos-26.05-xfce`. In **dom0**:

```sh
qvm-template remove nixos-26.05-xfce
```

6. If removal is refused, review the remaining dependencies; do not force it.
   **The removed TemplateVM's files and generations are now gone.** Install
   the verified signed replacement in **dom0**:

```sh
qvm-template --keyring ./template-key.asc install ./qubes-template-nixos-26.05-xfce-4.3.0-2.noarch.rpm
```

7. Review the new template's settings. Start it, check recovery below, and shut
   it down. Restore needed template files from the external backup.
8. Return each halted dependent qube and recorded default to the NixOS template.
   Start one AppVM and check it before starting the others.

### Rebuild a published image

If the signed download is unavailable, use an **x86_64 Linux builder with Nix
and Git**, outside dom0:

```sh
git clone https://github.com/cuzrawr/qubes-nixos qubes-nixos-recovery &&
  cd qubes-nixos-recovery &&
  git switch --detach v0.1.1 &&
  nix build .#template-rpm -o result-stable
```

- This example builds the `v0.1.1` stable XFCE image. Other profile outputs are
  listed in the [profile table](../README.md#versions).
- To recover an older image, select its matching release tag. An installed
  `v0.1.0` image needs that tag and RPM release `1` for same-version reinstall.
- Keep `flake.lock`; do not update inputs during recovery.
- [Sign the local RPM](distribution.md#sign-a-local-build), then transfer it
  using the README procedure. Building an RPM does not restore custom files.

## Check recovery

Run in a **normal user terminal inside the repaired template**, not a root
terminal:

```sh
systemctl --failed
systemctl --user --failed
df -h / /rw
```

- Both unit lists should be empty. Inspect any failure; do not reset every
  failed unit merely to clear the display.
- Zero failed units does not mean the journal contains no warnings/errors.
- Shut down the TemplateVM. Start one dependent AppVM; check important files,
  applications and networking before starting the others.
- Keep the previous template, source copies and backup until these checks pass.

If only `qubes-nixos-update` remains failed from the original attempt, save its
journal. After restoring and checking both system and source, clear that one
job's failed state in the template terminal:

```sh
sudo systemctl reset-failed qubes-nixos-update
systemctl --failed
```

This does not retry the update or remove its journal.

[backup]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-back-up-restore-and-migrate.html
[restore-cli]: https://doc.qubes-os.org/projects/core-admin-client/en/latest/manpages/qvm-backup-restore.html
[template-cli]: https://doc.qubes-os.org/projects/core-admin-client/en/latest/manpages/qvm-template.html
[postprocess]: https://github.com/QubesOS/qubes-core-admin-client/blob/release4.3/qubesadmin/tools/qvm_template_postprocess.py
[nixos-rollback]: https://nixos.org/manual/nixos/stable/#sec-rollback
