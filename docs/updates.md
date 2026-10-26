# Updating

| Image | Template name |
| --- | --- |
| Stable XFCE | `nixos-26.05-xfce` |
| Unstable XFCE | `nixos-unstable-xfce` |
| Stable minimal | `nixos-26.05-minimal` |
| Unstable minimal | `nixos-unstable-minimal` |

All use the stock Qubes external kernel. Examples below use **stable XFCE**.

## Recommended: update packages in the existing template

**Use this for normal software and security updates. It does not reinstall the
image or erase your configuration, template home, or AppVM files.**

For Debian/Fedora, Qubes recommends **Qubes Update**, followed by shutting down
the template and restarting its AppVMs. Template Manager's **Upgrade** button
is a different operation: it replaces the template image.
[Official update instructions][qubes-update].

NixOS has no backend in the central Qubes updater. Use the service below for
this template. It uses Nix, the Qubes update proxy and Qubes notifications;
it does not provide all checks performed by the central updater.

### 1. Prepare

- Keep a current [backup](#before-changing-a-template), including the TemplateVM.
- Save work in the template and its AppVMs. You will restart them after updating.
- Keep the template's NetVM setting at its normal value of `none`. Updates use
  the configured Qubes UpdateVM/proxy; it must have working Internet access.
- Do not run a second rebuild or edit `/etc/nixos` while the update runs.

**In a dom0 terminal:**

```sh
qvm-run -p --no-gui -u root nixos-26.05-xfce 'df -h / /rw; readlink -f /run/current-system /nix/var/nix/profiles/system'
```

Keep the two system paths in this output for recovery.
Check the Qubes disk-space widget for free space in the host storage pool too.
A full pool can affect other qubes too. If needed, follow [resizing](resizing.md).
Do not delete rollback generations just to force a large update through.

### 2. Run the update

**In dom0:**

```sh
qvm-run -p --no-gui -u root nixos-26.05-xfce 'systemctl start qubes-nixos-update.service'
```

This starts the template if needed and waits for the update to finish. Silence
while it runs is normal. It may take time to download or build packages.

**Then, in dom0:**

```sh
qvm-run -p --no-gui -u root nixos-26.05-xfce 'systemctl show qubes-nixos-update.service -p Result -p ExecMainStatus; journalctl -b -u qubes-nixos-update.service -n 60 --no-pager'
```

The start command must succeed. Check for `Result=success`, `ExecMainStatus=0`
and `Update applied` from the latest attempt. An older success message does not
prove this attempt worked. If the command fails or the latest attempt reports an
error, **stop here** and use [failed-update recovery](recovery.md#failed-package-update).
Do not start an RPM reinstall to fix a failed package download or Nix evaluation.

The service:

- Saves the previous lock file in `/var/lib/qubes/flake.lock.previous`.
- Refreshes the configured nixpkgs input and builds a new system generation.
- Activates it, then clears the update notification after success.
- Keeps existing rollback generations. Earlier lock backups get numbered copies.

It **does not update this project's integration files or pinned Qubes guest
components**. Those need an [integration upgrade](#update-the-integration).

### 3. Check and restart

**In dom0:**

```sh
qvm-run -p --no-gui -u root nixos-26.05-xfce 'systemctl --failed --no-pager'
qvm-run -p --no-gui nixos-26.05-xfce 'systemctl --user --failed --no-pager'
```

Both lists should contain zero failed units. If a unit failed, keep its logs and
follow [recovery](recovery.md). Zero failed units does not mean an empty error log;
known upstream messages are listed in [testing](testing.md#journal-and-kernel-diagnostics).

**Data-loss point:** shutting down a qube loses unsaved work. Stopping a
disposable discards its contents. Save or copy out anything needed first.

**In dom0, after saving work:**

```sh
qvm-shutdown --wait nixos-26.05-xfce
```

In **Qubes Manager**, find the qubes whose Template is `nixos-26.05-xfce`.
Shut them down normally, then start them again. Include disposable templates;
stop old disposables and launch new ones. Arrange another network/input provider
before restarting service qubes that you depend on.

Open one ordinary AppVM first. Check your applications, files and networking.
Then restart the others. Already-running AppVMs keep the old template root until
restarted after template shutdown.

### Optional: XFCE update window

Instead of step 2, run **in dom0**:

```sh
qvm-run --service nixos-26.05-xfce qubes.InstallUpdatesGUI
```

This opens a window for the same update job. Closing the window does not stop
the update. Wait for `Update applied`, then perform step 3. Minimal templates
use the headless command above.

### Retry a build without changing package pins

Use this after correcting a configuration or download failure when you want to
keep the current `flake.lock`. It does not refresh package inputs.

**In dom0:**

```sh
qvm-run -p --no-gui -u root nixos-26.05-xfce 'nixos-rebuild build --flake /etc/nixos#nixos --no-update-lock-file'
```

**Stop if the build fails.** If it succeeds, activate it **from dom0**:

```sh
qvm-run -p --no-gui -u root nixos-26.05-xfce 'nixos-rebuild switch --flake /etc/nixos#nixos --no-update-lock-file'
```

Then follow the checks and restart order in step 3. Activation changes the running
system; it does not wipe user files. An activation failure needs recovery before
continuing.

## Which method changes or deletes what?

| Method | Template configuration and files | Existing AppVM data |
| --- | --- | --- |
| Routine update above | Keeps `/etc/nixos` except refreshed `flake.lock`; keeps home, `/usr/local` and retained generations | Keeps private data; new software appears after restart |
| Reviewed integration source upgrade | Replaces integration source; local settings must be carried forward; keeps home and retained generations | Keeps private data; application changes take effect after restart |
| Install a different template and reassign AppVMs | Leaves the old template intact; new template starts with its own defaults | Keeps private data, but applications may migrate it when first opened |
| Template Manager Upgrade, `qvm-template upgrade`, `reinstall` or `downgrade` | **Replaces root AND clears template private data**, including `/etc/nixos`, `/home`, `/usr/local` and old generations | Does not erase separate AppVM private volumes; root changes on restart |
| `qvm-template remove` / Qubes Manager delete | **Deletes the selected template and its data**; dependencies must be reassigned | Does not migrate software or configuration for you |
| `qvm-template purge` | **Deletes the template AND dependent qubes and their data** | **Data is deleted**; not an update procedure |

Saved AppVM files normally live in `/home` or `/usr/local`. Files placed only on
an AppVM's root filesystem are discarded on restart, regardless of the update
method. A disposable has no persistent user-data guarantee.

New application versions can change databases, browser profiles or file formats.
**NixOS rollback restores software, not those files.** Keep a backup from before
the update if you may need to return to an older application version.

Native image-replacement behavior was checked against Qubes 4.3's installed
[post-install helper][postprocess]. Confidence: high. It is not a NixOS-specific
wipe operation. [Qubes template persistence][persistence].

## Before changing a template

Do this before an integration upgrade, image replacement or recovery operation.
For routine package updates, keep a current backup and save any recent work.

### Record what you use

**In Qubes Manager:**

1. Find every AppVM and disposable template using `nixos-26.05-xfce`.
2. Record custom settings: NetVM, services, kernel, memory and any attached devices.
3. Keep the backup destination, UpdateVM and network/input providers usable.

**In dom0:**

```sh
qvm-prefs nixos-26.05-xfce
qvm-features nixos-26.05-xfce
```

Save these settings privately. They can contain names and infrastructure details.

### Save an editable configuration copy

**In dom0**, open a terminal in the template:

```sh
qvm-run nixos-26.05-xfce xfce4-terminal
```

**In that template terminal**, run this block:

```sh
umask 077
archive="$HOME/nixos-config-$(date +%Y%m%d-%H%M%S).tar.gz"
sudo tar -C /etc -czf - nixos > "$archive" &&
  tar -tzf "$archive" &&
  qvm-copy "$archive"
```

Choose a separate backup qube in the copy dialog. In that qube, check the archive
in `QubesIncoming/nixos-26.05-xfce/`. Open it and confirm your configuration files
are present. Also save imported files outside `/etc/nixos` and any required
home or `/usr/local` files.

**An archive left inside the TemplateVM is lost during image replacement.**
This copy is for convenient configuration recovery; it does not replace a full
Qubes backup. It may contain secrets from your configuration; keep it private.

### Make and verify a Qubes backup

1. Save work; shut down the TemplateVM and its persistent dependent qubes.
   Copy needed disposable files out before stopping the disposable.
2. Open **Backup Qubes**. Explicitly select the TemplateVM and every persistent
   qube whose data you need. Check the final selection summary.
3. Choose a destination outside those qubes, preferably a separate backup device.
   Keep the backup passphrase somewhere you can access if these qubes fail.
4. Complete the backup. Open **Restore Backup** for that archive and select
   **Verify backup integrity, do not restore the data**. Verify the selected qubes.
5. Stop if backup or verification reports an error. Keep the archive until the
   updated template and all dependent applications have been checked.

Integrity verification detects corruption; it does not prove that you selected
everything needed or that the restored system boots. A restore under another
name provides a stronger check. [Official backup instructions][backup].

## Update the integration

Package updates do not fetch new files from this repository. Integration releases
can change boot ordering, guest-tool packaging or optional roles.
[Release changes](../versions.txt) | [configuration options](configuration.md).

Choose one route:

- **Customized template:** stage the new source, retain and review local settings,
  build it, then activate. No image replacement is required.
- **Stock template:** a signed image upgrade gives the published defaults, but
  still clears that TemplateVM's private volume. Back up first.

### Source upgrade for a customized template

The installed `/etc/nixos` is an ordinary writable source tree, without `.git`.
`git pull` there is not an update procedure.

Wait for any running update or rebuild to finish before editing or staging.

**Before activation:** keep a verified backup and a complete copy of `/etc/nixos`
outside the template. Record its `system.stateVersion`; do not raise that setting
just because you are upgrading.

Source migration requires reviewing local settings. There is no safe universal
command that can merge arbitrary custom modules with a new release.

The steps below stage `v0.1.1`. Check [test coverage](testing.md) and
[release changes](../versions.txt) before applying them to a customized template.
Use a published release tag; do not select `main` for a routine upgrade.

1. **In dom0**, open an administrator terminal in the template:

   ```sh
   qvm-run -u root nixos-26.05-xfce xterm
   ```

2. **In that root terminal**, fetch and stage the source:

   ```sh
   release_ref=github:cuzrawr/qubes-nixos/v0.1.1
   source=$(nix flake metadata --json --no-write-lock-file "$release_ref" |
     python3 -c 'import json,sys; print(json.load(sys.stdin)["path"])') &&
     test -d "$source" &&
     test ! -e /etc/nixos.candidate && test ! -L /etc/nixos.candidate &&
     cp -a "$source" /etc/nixos.candidate &&
     chmod -R u+w /etc/nixos.candidate
   ```

   Stop on any error. If the candidate directory already exists, inspect it;
   do not overwrite an earlier recovery attempt. This fetches source and does
   not activate anything. Keep its complete tree and `flake.lock` together.

3. Review your local settings against the new defaults:

   ```sh
   diff -u /etc/nixos/configuration.nix /etc/nixos.candidate/configuration.nix
   ```

   `diff` returns status 1 when files differ; that is expected. If
   `configuration.nix` is your **only** edited file and has no local imports,
   retain it with:

   ```sh
   cp -a /etc/nixos/configuration.nix /etc/nixos.candidate/configuration.nix
   ```

   Otherwise, merge your changes into the candidate before proceeding. Include
   imported local modules and external files. If you edited `flake.nix`,
   `modules/`, `profiles/` or `pkgs/`, review each edit against the new release.
   Preserve the original `system.stateVersion`, update target and selected
   inputs. Do not copy the whole old directory over the new integration.

4. Build the candidate without activating it:

   ```sh
   nixos-rebuild build --flake /etc/nixos.candidate#nixos --no-update-lock-file
   ```

   **Stop if this fails.** The existing source and running system are untouched.
   A successful build alone does not prove Qubes boot, networking or GUI.

5. Preserve the existing source, then put the candidate in its normal location:

   ```sh
   test ! -e /etc/nixos.before-upgrade && test ! -L /etc/nixos.before-upgrade &&
     mv /etc/nixos /etc/nixos.before-upgrade &&
     mv /etc/nixos.candidate /etc/nixos
   ```

   Stop on any error. If the first rename succeeded and the second failed,
   restore `/etc/nixos.before-upgrade` to `/etc/nixos` before continuing.
   These copies do not replace your external backup: an RPM replacement wipes
   both. Renaming source does not yet change the running system.

6. Activate the reviewed source:

   ```sh
   nixos-rebuild switch --flake /etc/nixos#nixos --no-update-lock-file
   ```

   Follow the routine update's unit checks and restart order. Test one AppVM
   before restarting the others. Keep the previous source and system generation
   until the new setup works. If activation fails, follow recovery below.

**Data-loss points:** overwriting source files loses edits that were not backed
up. Activation may change service state or application data formats. It does not
clear template or AppVM private volumes. Failed activation can leave some services
changed; see [generation recovery](recovery.md#restore-a-generation).

### 0.1.0 to 0.1.1

Choose the method before starting:

| Your template | Procedure |
| --- | --- |
| Keep custom packages, settings and template files | [Stage the v0.1.1 source](#source-upgrade-for-a-customized-template), review local changes, build, then activate |
| Replace it with the signed defaults | [Upgrade the image](#replace-with-a-newer-signed-image); back up first because root and template private data are cleared |

- The two XFCE template names stay the same; their RPM release changes from
  `4.3.0-1` to `4.3.0-2`.
- Minimal templates are separate installations. An XFCE upgrade does not select
  minimal or remove its desktop applications.
- Routine package updates alone do not install these integration changes.
- Retain `system.stateVersion` and review local imports and custom modules.
  Tested source migrations do not cover arbitrary local modifications.
- Keep the external backup, previous source and retained generations until the
  updated template and a dependent AppVM have passed the checks below.

## Replace with a newer signed image

**This is an image reset, not the recommended routine package update.**
Use it only when you want the published image and have backed up everything
needed from the TemplateVM. AppVM private data remains separate.

1. Complete [backup and verification](#before-changing-a-template).
2. Save work and shut down the template and **all** dependent qubes, including
   running disposables. Arrange replacement service qubes first if needed.
3. Check the Qubes pool has room for the download, old root and incoming image.
   Compressed RPM size alone is not the required free space.
4. In dom0, open Template Manager:

   ```sh
   qvm-template-gui
   ```

5. Refresh repository data. Select the installed `nixos-26.05-xfce`, choose
   **Upgrade**, and verify the offered version against the release notes.

   **Data-loss point:** starting replacement clears the TemplateVM's old root
   and private data. This includes its home, installed custom software,
   `/etc/nixos`, `/usr/local`, and rollback generations. A Nix rollback cannot
   restore them afterward.

6. Complete import without interrupting power. If no newer image is offered,
   check release availability and repository setup. Do not delete the template
   to force an update.

The equivalent **dom0** command, after steps 1-3, is:

```sh
qvm-template --repoid=qubes-nixos --refresh upgrade nixos-26.05-xfce
```

For a downloaded signed RPM, complete the [transfer and signature setup](../README.md#install-a-signed-rpm),
then run **in dom0**:

```sh
qvm-template --keyring ./template-key.asc upgrade ./qubes-template-nixos-26.05-xfce-4.3.0-2.noarch.rpm
```

This has the same data loss as the GUI upgrade. Do not use `--nogpgcheck`.

### Check the replacement before using it

1. Review template settings against your saved copy. Native post-install processing
   can reset the NetVM to its default. Restore intentional settings.
2. Run the system/user failed-unit commands from the routine update procedure.
   Do not treat an import exit status alone as proof of successful guest startup.
3. Reapply reviewed custom configuration; restore needed template files from
   backup. Do not copy an old integration tree over the new one.
4. Save work, shut down the template, then start one AppVM. Check applications,
   files, clipboard and networking. Continue with the others only after it works.
5. Keep your backups. If the replacement fails, follow [recovery](recovery.md).

## Move to another NixOS release or profile

Prefer installing a separately named template, testing it, then switching AppVMs.
This keeps the old template available and follows Qubes' [template migration
approach][templates]. Do not change an XFCE template into minimal by deleting
packages blindly.

1. Back up the old TemplateVM and AppVMs.
2. Install the desired published template. Apply its updates and needed software.
3. Save work and shut down one AppVM. In **Qubes Settings**, select the new
   template for that AppVM. Start it and check your applications and saved files.
4. Repeat for the other AppVMs and disposable templates. Keep the old template
   until the new setup and backups work.

Changing the Template setting preserves the AppVM's private volume. It does not
copy software declarations from the old TemplateVM. New applications may migrate
private data; switching back to the old template does not undo that migration.

[qubes-update]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-update.html
[backup]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-back-up-restore-and-migrate.html
[persistence]: https://doc.qubes-os.org/en/r4.3/user/templates/templates.html#inheritance-and-persistence
[templates]: https://doc.qubes-os.org/en/r4.3/user/templates/templates.html#switching
[postprocess]: https://github.com/QubesOS/qubes-core-admin-client/blob/release4.3/qubesadmin/tools/qvm_template_postprocess.py
