# Architecture

Confidence: high for the pinned sources and recorded tests. Coverage and
remaining checks: [testing](docs/testing.md), [feature gaps](docs/feature-gaps.md).

## Boot

| Choice | Reason / constraint |
| --- | --- |
| Stock Qubes PVH kernel, initramfs and matching modules | Native kernel selection and updates in Qubes |
| `boot.kernel.enable = false`, `boot.initrd.enable = false` | Enter NixOS through `boot.loader.initScript` at `/sbin/init`; a foreign initramfs does not run NixOS initrd activation |
| External modules at `/lib/modules` | Point the `kmod-static-nodes` condition there; retain normal kmod/tmpfiles device creation |
| No replacement init script or kernel patch | Preserve upstream boot interfaces |

- At the pinned revisions, enabling both NixOS initrd options selects direct
  systemd entry instead of the required stage-2 activation script.
- NixOS 26.05 deprecates scripted stage 1 for removal in 26.11. This does not
  deprecate initramfs generally or the external stage-2 entry point.
- Test stable and pinned unstable separately; do not infer future compatibility.

Sources: [26.05 announcement](https://nixos.org/blog/announcements/2026/nixos-2605/),
[activation](https://github.com/NixOS/nixpkgs/blob/5e2305d577ca00acbba631b05cb1094d172b29f3/nixos/modules/system/activation/top-level.nix),
[init-script loader](https://github.com/NixOS/nixpkgs/blob/5e2305d577ca00acbba631b05cb1094d172b29f3/nixos/modules/system/boot/loader/init-script/init-script.nix),
[Qubes kernel management](https://doc.qubes-os.org/en/r4.3/user/advanced-topics/managing-vm-kernels.html).

## Configuration and persistence

- Ordinary shared TemplateVM; `/nix` stays on root. AppVMs inherit native Qubes
  snapshots. No shared writable store or per-AppVM activation framework.
- `/home`, `/usr/local` and configured bind directories use private storage.
  Disposables retain native Qubes isolation.
- Complete writable flake in `/etc/nixos`; normal flake and `nixos-rebuild`
  commands. Shut down the template and restart AppVMs after changes.
- Persistent AppVM profiles do not preserve newly installed store objects when
  root resets. Install shared software in the TemplateVM.
- Retain generations for rollback. RPM replacement replaces root and clears
  the TemplateVM's private volume, including `/etc/nixos`, `/home` and
  `/usr/local`. An in-template NixOS rebuild does not replace these volumes.
- [Recovery](docs/recovery.md): configuration backups, rebuilds and replacement.

Source: [Qubes template implementation](https://doc.qubes-os.org/en/r4.3/developer/system/template-implementation.html).

## Root resize ordering

- Confirmed cycle: early resize waits for udev; a network udev job waits for
  `qubes-network-uplink@`; that service waits for initialization; initialization
  waits for resize.
- A longer qrexec timeout did not fix it: `udevadm settle` failed after 120
  seconds, leaving the filesystem smaller than the root volume.
- Disable the early `qubes-rootfs-resize` unit. Run the unchanged helper as
  `qubes-nixos-rootfs-resize`, with normal systemd dependencies, after
  `network.target` and before `qubes-qrexec-agent.service`.
- Preserve private-volume initialization and bind-mount ordering.
- `network.target` orders local network setup, not Internet availability.
- Cost: maintain one small declarative service definition. No custom resize
  script, udev-rule patch, exit-code suppression or partition conversion.
- Verified networked growth on both pins at the normal 60-second qrexec timeout;
  cold/live growth preserved data with zero failed system/user units.
  [Measurements and remaining cases](docs/testing.md).

| Alternative | Reason not selected |
| --- | --- |
| Increase qrexec timeout | The resize helper still timed out; the filesystem did not grow |
| Add `--no-block` to the network udev rule | Changes upstream behavior; outside the no-patching boundary |
| Move networking into early boot | Changes more services and their initialization requirements |
| Drop-in under the original unit name | systemd cannot remove the existing `Before=local-fs.target` dependency through a drop-in |
| Bare ext4 image without GPT | Supported by Qubes and the NixOS image builder; avoids this partition-resize branch for new images, but does not fix existing 0.1.0 roots |

Retain the existing image layout.
[Configuration](docs/configuration.md#boot-and-service-ordering),
[resizing procedure](docs/resizing.md).

Sources: [resize helper](https://github.com/QubesOS/qubes-core-agent-linux/blob/v4.3.48/qubes-rpc/resize-rootfs),
[network rule](https://github.com/QubesOS/qubes-core-agent-linux/blob/v4.3.48/network/udev-qubes-network.rules),
[upstream issue](https://github.com/QubesOS/qubes-issues/issues/4419),
[systemd drop-in rules](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html),
[Qubes root-device selection](https://github.com/QubesOS/qubes-linux-utils/blob/v4.3.19/dracut/simple/init.sh),
[NixOS image layouts](https://github.com/NixOS/nixpkgs/blob/5e2305d577ca00acbba631b05cb1094d172b29f3/nixos/lib/make-disk-image.nix).

## Guest tools and path adaptation

- Pin Qubes releases compatible with Qubes 4.3. Retain native QubesDB, qrexec,
  GUI, audio, networking, firewall, storage and device components.
- Prefer upstream build variables. Otherwise use narrowly checked path/shebang
  substitutions; leave program logic and protocols unchanged.
- Bind required helpers to immutable store paths. Keep application discovery,
  optional commands, security wrappers and extension directories as explicit
  runtime interfaces.
- Map only installed package files and explicit dependencies. Record changes in
  `share/qubes-nixos/*-paths.json`. No general `/usr/bin` or `/usr/lib`
  compatibility tree and no directory-wide rewrite to the active profile.
- Benefit: another installed package cannot retarget a generation's dependencies;
  GC retains paths referenced by retained generations.
- Cost: new upstream paths may need packaging updates. Build checks catch missing
  executable targets; runtime tests must cover behavior.
- Register upstream services, udev rules, tmpfiles and desktop settings through
  NixOS. Use `security.wrappers` for setuid `qfile-unpacker`; its store executable
  remains mode 0755.
- Keep qrexec available during activation with `stopIfChanged = false`.
  Run upstream `qubes.PostInstall` after generation changes in fully persistent
  qubes to refresh menus and guest features.
- Use Qubes' Xorg/XFCE session hooks; dom0 supplies the window manager.
  Keep the upstream SVG handler unchanged; document its icon-conversion issue.
- Qubes selects its own Xorg config. Pass NixOS's native indexed font directory
  through a Files section, retaining `fontPath`/`filesSection` customization.
  Otherwise Xorg falls back to nonexistent compiled-in font directories.

Sources: [core agent](https://github.com/QubesOS/qubes-core-agent-linux),
[qrexec](https://github.com/QubesOS/qubes-core-qrexec),
[GUI/audio](https://github.com/QubesOS/qubes-gui-agent-linux).
Details: [adaptations](docs/adaptations.md).

## Updates

- Ordinary flake update and `nixos-rebuild`, run by a systemd oneshot.
  Concurrent starts share the job; closing the GUI does not stop it.
- Prevent the job from stopping itself during activation. Preserve failures.
- Headless interface: root qrexec starts the existing service. Graphical
  interface: distribution-specific `qubes.InstallUpdatesGUI` RPC.
- Downloads through UpdatesProxy; notifications through NotifyUpdates.
  Determine update eligibility from runtime persistence state.
- Keep NixOS identity and generic VMExec behavior unchanged.
- The central Qubes updater has no NixOS backend. Guest RPC support does not
  register one; central integration needs an upstream backend.

Sources: [updater dispatch](https://github.com/QubesOS/qubes-core-admin-linux/blob/8a6dd13e048f3cf8bcc349c8337560813303338b/vmupdate/agent/entrypoint.py),
[distribution-specific RPC](https://github.com/QubesOS/qubes-core-agent-linux/blob/4738333496c6b689207d8274d0f3425e796b6197/qubes-rpc/qubes.InstallUpdatesGUI).

## Optional roles

- Normal NixOS options select GUI, desktop, audio, USB/input, Split GPG 2,
  passwordless root and UpdateVM support.
- Keep the unchanged `install-pipewire` output separate from GUI files. The
  audio role selects its module, configuration, service drop-in and feature
  announcement; minimal also disables NixOS's default PipeWire activation.
- Installing components does not grant cross-qube access. Native service
  properties, device attachment and RPC policies control access.
- UpdateVM uses unchanged Qubes helpers, DNF 5, RPM and fakeroot, including on
  this non-RPM guest. NixOS itself remains managed by Nix.
- Expose `/usr/lib/qubes/qubes-download-dom0-updates.sh` with one tmpfiles link
  only while UpdateVM support is enabled: dom0 calls that exact path.
- Select librepo's upstream `USE_GPGME=OFF` option. Its RPM backend reports
  missing keys in the form DNF recognizes; the pinned GPGME backend reports a
  generic signature error and prevents key import. Verification stays enabled.

Sources: [DNF key handling](https://github.com/rpm-software-management/dnf5/blob/5.4.2.1/libdnf5/repo/repo_sack.cpp),
[librepo options](https://github.com/rpm-software-management/librepo/blob/1.20.0/CMakeLists.txt),
[audio installation target](https://github.com/QubesOS/qubes-gui-agent-linux/blob/v4.3.21/Makefile#L130).

## Minimal templates

- Four variants: stable/unstable, each XFCE/minimal. Retain full XFCE defaults.
- Share boot, persistence, guest tools and updates; separate Xorg from XFCE.
- Minimal keeps Xorg/xterm, ordinary Qubes networking, qrexec, clipboard and
  file transfer. This follows the official minimal-template model.
- Omit desktop applications, audio, converters, USB/input, Split GPG, UpdateVM
  tools and NetworkManager from minimal's selections. Keep required upstream
  dependencies; do not strip packages merely to reduce size.
- Passwordless administration stays enabled in XFCE and disabled in minimal.
  Administer minimal through dom0's `qvm-run -u root`.
- Keep optional roles configurable. Test their use and full-template upgrade
  compatibility before release.

Source: [Qubes minimal templates](https://doc.qubes-os.org/en/r4.3/user/templates/minimal-templates.html).

## Build and distribution

- Locked flake exports modules, packages, images and native template RPMs.
- Use nixpkgs' image builder and upstream Qubes template packaging.
  QEMU TCG supports finalization without KVM.
- Package split sparse `root.img`, template metadata and three application-menu
  lists. Test native `qvm-template` installation and its post-install RPC.
- Sign outside Nix. Private keys never enter Git, derivations, the store, images
  or CI. Clients verify RPMs against the selected public key.
- GitHub Releases stores payloads; Pages serves small signed metadata.
  One-time public-key/repository setup enables native Template Manager use.
  This does not add the project to Qubes' official community repository.
- CI uses pinned actions and read-only source-check permissions. Pages verifies
  prepared public metadata and uses deployment-specific permissions.
- Image builds and Qubes runtime acceptance remain separate from hosted checks.

Sources: [template packaging](https://doc.qubes-os.org/en/r4.3/developer/system/template-manager.html),
[template builder](https://github.com/QubesOS/qubes-linux-template-builder),
[qvm-template](https://doc.qubes-os.org/projects/core-admin-client/en/latest/manpages/qvm-template.html).

## Size and rollback retention

- Strip debug sections from the block helper, including `etc/xen/scripts`,
  avoiding debug-only compiler references.
- Retain manual pages and one MBROLA voice per language; omit separate
  developer/Info documentation. Preserve selected applications and Qubes roles.
- Retain stock RPM for UpdateVM. Its build macros reference a compiler;
  separating runtime/build outputs belongs upstream. Disable the optional role
  when unneeded instead of deleting package files or changing tool lookup.
- Native deduplication; automatic collection below 1 GiB free, targeting 3 GiB.
  Generation deletion stays manual. No custom cleanup service.
- Retained generations remain GC roots. Automatic cleanup cannot reclaim their
  dependencies or guarantee enough room for a large build.

## Acceptance

- Zero failed system/user units after successful operations. Keep upstream
  journal diagnostics visible and record their limits.
- Inspect shutdown separately, including transient failures and final filesystem
  teardown. A successful next boot does not erase shutdown diagnostics.
- Test both pins: installation, repeat boot, agents, GUI, clipboard, files, audio,
  persistence, growth, disposables, networking, devices, updates and rollback.
- Evaluation and boot alone do not establish parity.
  [Test record](docs/testing.md), [adaptations](docs/adaptations.md).
