# qubes-nixos

NixOS TemplateVMs for Qubes OS 4.3, x86_64. Upstream guest tools, Xorg, XFCE
applications, Firefox, native clipboard, file transfer, devices and audio.

- Configuration: ordinary writable NixOS flake in `/etc/nixos`.
- Source: [GitHub](https://github.com/cuzrawr/qubes-nixos).
- Status: final RPM acceptance in progress; [test results](docs/testing.md).
- Public binaries: not published yet.
- License: integration code unlicensed for now; upstream licenses unchanged.

## Versions

| Variant | Template name | Build output | Configuration | Update input |
| --- | --- | --- | --- | --- |
| Stable 26.05 | `nixos-26.05-xfce` | `template-rpm` | `nixos` | `nixpkgs` |
| Development 26.11 | `nixos-unstable-xfce` | `template-rpm-unstable` | `nixos-unstable` | `nixpkgs-unstable` |

| Kernel/initrd variant | Availability |
| --- | --- |
| Stock Qubes external PVH kernel, initramfs and modules | Both templates |
| NixOS kernel or NixOS-built initrd | Not provided |
| NixOS deprecated scripted stage 1 | Not used |

Unstable is a pinned development snapshot, not released NixOS 26.11.
Exact revisions: [flake.lock](flake.lock). Boot rationale: [WHY.md](WHY.md).

## 1. Install and remove

### Local build

Requirements: x86_64 Linux, Nix with flakes, enough space for the store and image
copies. KVM is optional. Build outside dom0.

```sh
git clone https://github.com/cuzrawr/qubes-nixos
cd qubes-nixos

# Stable
nix build .#template-rpm -o result-stable

# Unstable
nix build .#template-rpm-unstable -o result-unstable
```

Output: unsigned RPM in the selected result directory.
[Sign with a separate working keyring](docs/distribution.md#sign-a-local-build).

### Install a signed RPM

Download/build in a transfer qube. Verify the public key's fingerprint through a
trusted channel. In dom0, set the matching RPM name:

```sh
# Stable
rpm=qubes-template-nixos-26.05-xfce-4.3.0-1.noarch.rpm
# Or unstable
# rpm=qubes-template-nixos-unstable-xfce-4.3.0-1.noarch.rpm

qvm-run --pass-io TRANSFER_QUBE 'cat /path/to/template-key.asc' > template-key.asc
qvm-run --pass-io TRANSFER_QUBE "cat /path/to/$rpm" > "$rpm"
qvm-template --keyring ./template-key.asc install "./$rpm"
```

| Installation source | Native method |
| --- | --- |
| Local build or GitHub Release RPM | Signature-checked command above |
| Configured RPM repository | `qvm-template install TEMPLATE` or Qubes Template Manager |
| Temporary repository definition | `qvm-template --repo-files ./qubes-nixos.repo install TEMPLATE` |
| Qubes backup | Qubes Backup Restore or `qvm-backup-restore` |

[Repository setup and GitHub hosting](docs/distribution.md).
The GUI uses configured repositories; it does not add arbitrary URLs.
No dom0 network access is required. This project is not in Qubes' official
community repository.

### Remove

1. Back up data; shut down the template and dependent qubes.
2. Choose replacement templates in Qubes Manager or with `qvm-prefs`.
3. Remove the old template:

```sh
qvm-prefs MY_APP template REPLACEMENT_TEMPLATE
qvm-template remove nixos-26.05-xfce
# Or: qvm-template remove nixos-unstable-xfce
```

| Other removal method | Effect |
| --- | --- |
| Qubes Template Manager: remove | Removes the selected installed template |
| Qubes Manager: delete, or `qvm-remove NAME` | Removes a manually created/cloned TemplateVM after dependencies are changed |
| `qvm-template purge TEMPLATE` | Also deletes dependent qubes and their data |
| Delete a `.repo` file | Removes the download source only |

### Recover or start again

- Broken configuration, template still boots: rollback in section 3.
- Replace its root from an RPM: `qvm-template --keyring ./template-key.asc reinstall ./TEMPLATE.rpm`.
- Full delete/build/install cycle: [recovery commands](docs/recovery.md).
- Reinstallation replaces `/etc/nixos` and other root changes; back up first.

## 2. Use and change software

1. Create an AppVM in Qubes Manager; select either template.
2. Run applications in the AppVM.
3. Edit `/etc/nixos/configuration.nix` in its TemplateVM:

```nix
environment.systemPackages = with pkgs; [
  atril claws-mail galculator geany keepassxc xarchiver htop
];
```

Add/remove list entries, then rebuild:

| Template | Command inside the TemplateVM |
| --- | --- |
| Stable | `sudo -i nixos-rebuild switch --flake /etc/nixos#nixos` |
| Unstable | `sudo -i nixos-rebuild switch --flake /etc/nixos#nixos-unstable` |

Shut down the template; restart its AppVMs. Menus refresh automatically.
Firefox is controlled by `programs.firefox.enable`, not that package list.

Default applications: Firefox, Thunar, Mousepad, XFCE Terminal, Atril, Claws Mail,
Galculator, Geany, KeePassXC, Xarchiver and XFCE utilities.

Clipboard between qubes: copy in the source app, Ctrl+Shift+C, focus destination,
Ctrl+Shift+V, paste in the destination app. Within a qube: normal app shortcuts.

| Location/action | Behavior |
| --- | --- |
| Template root, including `/nix` and `/etc/nixos` | Persistent; shared through normal Qubes snapshots |
| AppVM `/home`, `/usr/local` | Persistent on its private volume |
| AppVM root, including `/nix` | Resets from the template at restart |
| `nix profile install` in an AppVM | Profile can persist in home while its new store objects disappear at restart |
| Disposable changes | Discarded when the disposable stops |
| Template rebuild while an AppVM runs | AppVM keeps its old root until restarted after template shutdown |

[Critical settings and optional roles](docs/configuration.md): desktop, USB,
Split GPG 2, UpdateVM, update proxy, boot, persistence, trust and disk use.

## 3. Update and maintain

Inside the TemplateVM, first run `sudo -i` and `cd /etc/nixos`:

| Template | Refresh packages | Build and apply |
| --- | --- | --- |
| Stable | `nix flake update nixpkgs` | `nixos-rebuild switch --flake .#nixos` |
| Unstable | `nix flake update nixpkgs-unstable` | `nixos-rebuild switch --flake .#nixos-unstable` |

Then `poweroff` and restart dependent AppVMs. Keep TemplateVMs without a NetVM;
Nix uses the native UpdatesProxy.

Graphical update, from dom0:

```sh
qvm-run --service nixos-26.05-xfce qubes.InstallUpdatesGUI
# Or: qvm-run --service nixos-unstable-xfce qubes.InstallUpdatesGUI
```

- Closing the window leaves the update running.
- Progress: `sudo journalctl -fu qubes-nixos-update` in the template.
- Central Qubes updater: no NixOS backend; use these commands/RPC.
- Failed evaluation/build: running generation stays available.
- Failed activation: inspect system/user units and roll back; activation is not
  a transaction across all running services.

```sh
sudo nixos-rebuild switch --rollback --no-reexec
```

Rollback changes the generation, not edited source files. Restore those from
version control; the update RPC keeps `/var/lib/qubes/flake.lock.previous`.
Shut down the template and restart its AppVMs afterward.

| Maintenance | Policy/command |
| --- | --- |
| Deduplication | Enabled during store insertion |
| Automatic GC during builds | Below 1 GiB free; target 3 GiB; retained generations protected |
| Collect unreferenced objects | `sudo nix-store --gc` |
| Delete old rollback choices, after checking replacements | `sudo nix-collect-garbage --delete-older-than 30d` |
| Increase root space, in dom0 | `qvm-volume resize TEMPLATE:root SIZE` |
| Builder cleanup | Remove obsolete `result-*` links, then `nix-store --gc` |
| Backups | Include TemplateVM configuration and AppVM data in native Qubes backups |

Updating nixpkgs does not update this integration or pinned Qubes components.
[Integration updates, release upgrades and recovery](docs/recovery.md).
Keep `system.stateVersion` unchanged during routine upgrades.

## Repository and compatibility

| Files | Purpose |
| --- | --- |
| `configuration.nix` | Default software and optional roles |
| `flake.nix`, `flake.lock` | Builds, configurations and pins |
| `modules/` | NixOS guest integration |
| `pkgs/` | Upstream guest-tool packaging |
| `lib/` | Root image and native template RPM |
| `scripts/`, `tests/` | Signing and checks |
| `WHY.md`, `docs/` | Decisions, operation, tests and upstream proposals |

[Complete file list](docs/files.md).
Custom flakes can import `nixosModules.qubes` and call `lib.mkTemplate`.
Diagnostic `boot-test`, `core-test` and `desktop-test` images enable console
autologin; they are not normal templates.

Adaptations: checked paths/shebangs, Python wrappers, NixOS privilege wrappers,
upstream service registration, Xorg session hooks, merged helper directories,
Nix update RPC, one fixed UpdateVM helper link, and librepo's RPM backend.
No Qubes protocol or dom0 patches. [Full list and tradeoffs](docs/adaptations.md).

Upstream topics: external kernel modules/initramfs handoff, configurable Qubes
paths, NixOS central updater, repository setup GUI, SVG icons, D-Bus duplicate
registration, graphical-seat setup, and DNF/librepo key handling.
[Details and references](docs/adaptations.md#suggested-upstream-work).

Known limitations: missing icons for some XFCE entries; documented upstream
journal messages. Acceptance requires zero failed system and user units.
[GitHub Free: CI and distribution options](docs/github.md).
