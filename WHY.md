# Architecture

## Boot

Use the stock Qubes PVH kernel, initramfs and matching modules. Set
`boot.kernel.enable = false` and `boot.initrd.enable = false`; NixOS's
`boot.loader.initScript` supplies the stage-2 entry point at `/sbin/init`.
This keeps kernel selection and updates under normal Qubes management.

A foreign initramfs does not run NixOS initrd activation services. At the pinned
nixpkgs revisions, enabling both NixOS initrd options selects a direct systemd
entry point instead of the stage-2 activation script. Disabling the NixOS initrd
therefore controls the handoff, not just whether an extra image is built.

NixOS 26.05 deprecates scripted stage 1 for removal in 26.11. It does not
deprecate initramfs generally or the external stage-2 entry point used here.
Stable and pinned unstable are tested separately.

External modules live at `/lib/modules`. The condition on
`kmod-static-nodes.service` follows that directory so normal kmod and tmpfiles
create static device nodes. No replacement init script or kernel patch is used.

Sources: [NixOS 26.05 announcement](https://nixos.org/blog/announcements/2026/nixos-2605/),
[NixOS activation](https://github.com/NixOS/nixpkgs/blob/5e2305d577ca00acbba631b05cb1094d172b29f3/nixos/modules/system/activation/top-level.nix),
[init-script loader](https://github.com/NixOS/nixpkgs/blob/5e2305d577ca00acbba631b05cb1094d172b29f3/nixos/modules/system/boot/loader/init-script/init-script.nix),
[Qubes kernel management](https://doc.qubes-os.org/en/r4.3/user/advanced-topics/managing-vm-kernels.html).

## Configuration and persistence

Use an ordinary shared TemplateVM with `/nix` on its root volume. AppVMs inherit
that root through Qubes snapshots; `/home`, `/usr/local` and configured bind
directories use the private volume. Disposable qubes retain Qubes' normal
isolation rules. No shared writable store or per-AppVM activation framework is
introduced.

Ship a complete writable flake in `/etc/nixos`. Manage it with normal
`nixos-rebuild` and flake commands. After a template change, shut down the
template and restart its AppVMs. A user profile in an AppVM's persistent home
does not preserve newly installed store objects across root resets.

Keep generations for rollback. Replacing a template RPM replaces its root,
including `/etc/nixos`; it is distinct from rebuilding NixOS in the template.
[Recovery](docs/recovery.md) covers configuration backups and both operations.

Source: [Qubes template implementation](https://doc.qubes-os.org/en/r4.3/developer/system/template-implementation.html).

## Guest tools and path adaptation

Package pinned Qubes releases compatible with Qubes 4.3. Use their native
QubesDB, qrexec, GUI, audio, networking, firewall, storage and device components.
Development branches are not substituted for compatible releases.

Use upstream build variables first. Where paths are hardcoded, apply narrowly
checked path or interpreter substitutions; leave program logic and protocols
unchanged. Package-owned helpers and required dependencies use immutable store
references. Application discovery, optional commands, security wrappers and
extension directories remain explicit runtime interfaces.

Store references retain dependencies for each generation. Adding another Nix
package cannot retarget them. The cost is packaging maintenance when upstream
introduces new paths: build-time checks catch missing executable targets, but
runtime tests are still required. A global FHS compatibility tree would add a
shared namespace and could hide missing dependencies.

The path helper maps only files installed by the package plus explicit mappings.
It records substitutions under `share/qubes-nixos/*-paths.json`. There are no
general `/usr/bin` or `/usr/lib` compatibility links or directory-wide rewrites
to the active system profile.

Register upstream services, udev rules, tmpfiles and desktop settings through
NixOS modules. Use `security.wrappers` for the upstream setuid file unpacker;
its store executable stays mode 0755. Keep qrexec available during activation
with `stopIfChanged = false`, allowing dependent user services to restart.
Run upstream `qubes.PostInstall` after generation changes in fully persistent
qubes to refresh menus and guest features.

Use Xorg and XFCE applications through the Qubes session hooks. Dom0 supplies
the window manager. Keep the upstream SVG handler unchanged; its known icon
conversion failure is documented in [adaptations](docs/adaptations.md).

Sources: [core agent](https://github.com/QubesOS/qubes-core-agent-linux),
[qrexec](https://github.com/QubesOS/qubes-core-qrexec),
[GUI and audio](https://github.com/QubesOS/qubes-gui-agent-linux).

## Updates

Use the distribution-specific `qubes.InstallUpdatesGUI` RPC to run ordinary
flake updates and `nixos-rebuild`. A systemd oneshot keeps the update running
if its window closes. Its activation settings prevent it from stopping itself
while switching configurations. Serialize rebuilds and report failure when
activation fails.

Use Qubes UpdatesProxy for downloads and NotifyUpdates for notifications.
Determine update eligibility from runtime persistence state. Keep generic
VMExec behavior and the guest's NixOS identity unchanged.

The central Qubes updater has no NixOS backend. The guest RPC does not register
one, so full central-updater support needs an upstream backend. The supported
RPC and normal NixOS commands are the available update interfaces.

Sources: [updater dispatch](https://github.com/QubesOS/qubes-core-admin-linux/blob/8a6dd13e048f3cf8bcc349c8337560813303338b/vmupdate/agent/entrypoint.py),
[distribution-specific update RPC](https://github.com/QubesOS/qubes-core-agent-linux/blob/4738333496c6b689207d8274d0f3425e796b6197/qubes-rpc/qubes.InstallUpdatesGUI).

## Optional roles

Expose desktop, USB/input forwarding, Split GPG 2 and UpdateVM support as normal
NixOS options. Installing these components does not grant cross-qube access;
Qubes service properties, device attachment and RPC policies select access.

The UpdateVM role requires DNF and RPM even on non-RPM guests. Use unchanged
Qubes helpers with DNF 5, RPM and fakeroot. NixOS itself remains managed by Nix.
Dom0 invokes `/usr/lib/qubes/qubes-download-dom0-updates.sh` directly, so expose
that single entry point with a tmpfiles link only while the role is enabled.

Select librepo's upstream `USE_GPGME=OFF` build option for these helpers. With
the pinned GPGME backend, DNF 5 receives a generic signature error for a missing
repository key and cannot start key import. The RPM backend supplies the error
DNF recognizes. Signature checks remain enabled.

Sources: [DNF key handling](https://github.com/rpm-software-management/dnf5/blob/5.4.2.1/libdnf5/repo/repo_sack.cpp),
[librepo build options](https://github.com/rpm-software-management/librepo/blob/1.20.0/CMakeLists.txt).

## Build and distribution

A locked flake exposes the module, packages, images and native template RPMs.
Use nixpkgs image-building facilities and the upstream Qubes template builder.
QEMU TCG allows image finalization without requiring KVM.

Package a split sparse tar archive of `root.img`, template metadata and the
three application-menu lists. Validate installation with `qvm-template`,
including its post-install RPC.

Sign outside the Nix build. Private keys must not enter Git, derivation inputs,
the Nix store, images or CI. Build outputs remain unsigned until the explicit
signing step. Clients verify RPM signatures against the selected public key.

Use GitHub Releases for RPM payloads and Pages for small signed repository
metadata. Qubes Template Manager can consume this third-party repository after
one-time public-key and `.repo` setup in dom0. Publishing it does not add it to
Qubes' official community repository.

Hosted CI checks source with read-only repository permissions and pinned
actions. The Pages deployment receives prepared public metadata, verifies its
signature and publishes it with deployment-specific permissions. Image builds
and Qubes runtime acceptance remain separate from hosted source checks.

Sources: [template packaging](https://doc.qubes-os.org/en/r4.3/developer/system/template-manager.html),
[template builder](https://github.com/QubesOS/qubes-linux-template-builder),
[qvm-template](https://doc.qubes-os.org/projects/core-admin-client/en/latest/manpages/qvm-template.html).

## Size and rollback retention

Strip debug sections from the block helper, including its unusual
`etc/xen/scripts` installation directory, to avoid retaining debug-only compiler
references. Keep manual pages, omit separate developer/Info documentation, and
use one MBROLA voice per language. Desktop applications and Qubes roles remain
available through the normal configuration.

Retain the stock RPM package for UpdateVM support. Its build macros keep a
compiler in the closure. Removing that dependency requires changing the
package's tool lookup or separating its build and runtime outputs upstream.
The integration does neither. Users who do not need the UpdateVM role can
disable that role through its existing NixOS option.

Enable native Nix deduplication and collect unreferenced paths below 1 GiB free,
targeting 3 GiB. Keep generation deletion manual. Every retained generation
remains a GC root; automatic cleanup cannot reclaim its live dependencies or
guarantee enough space for a large build. No custom cleanup service is needed.

## Acceptance

Require zero failed system and user units after successful operations.
Document upstream journal diagnostics without filtering them or counting them
as passed integration checks. Known issues and possible upstream changes are
listed in [adaptations](docs/adaptations.md).

Inspect shutdown consoles separately. Record transient failed units as well as
the final filesystem teardown result; a clean next boot does not erase those
diagnostics. The test record includes comparisons with stock Qubes guests.

Check both stable and pinned unstable on Qubes, including installation, repeated
boot, guest agents, GUI, clipboard, file transfer, audio, persistence, storage
growth, disposable isolation, networking, device roles, updates and rollback.
Evaluation and boot alone do not establish feature parity. Coverage and limits
are listed in [test results](docs/testing.md).
