# Adaptations and upstream proposals

This is the list of compatibility changes, including the parts that could
reasonably be called workarounds. No Qubes protocol or dom0 code is patched.

## What is changed

| Change | Reason and cost |
| --- | --- |
| Bind named commands to store paths | Qubes uses FHS paths. Nix must retain each dependency explicitly. A new upstream path can need packaging changes. |
| Fix shebangs and Python wrappers | Interpreters and imported modules must be present outside a distribution-wide Python environment. |
| Relocate each package's own installed paths | Upstream scripts expect a shared `/usr`. The helper only maps files actually installed by that package, plus explicit mappings. |
| Use system-profile paths for application discovery and extensions | These deliberately follow the active configuration. They cannot be fixed to one application's output. |
| Expose `qfile-unpacker` through NixOS security wrappers | The store cannot supply its setuid privilege. The underlying executable remains mode 0755. |
| Register upstream services, udev rules and tmpfiles in NixOS | A package install does not run Fedora presets or Debian maintainer scripts. Ordering and runtime conditions come from upstream. |
| Restart qrexec after activation | NixOS user services need the transport during activation. `stopIfChanged = false` avoids stopping it before they restart. |
| Run the upstream post-install hook after generation changes | Refresh application menus and guest features, like the upstream DNF transaction hook. A NixOS oneshot service tracks the system profile. |
| Set the static-device-node condition to `/lib/modules` | The kernel and modules are supplied by Qubes, not a NixOS kernel closure. Normal kmod/tmpfiles then create nodes such as `loop-control`. |
| Merge upstream Xen helper directories | Xen, the core agent and Linux utilities each install helpers used by network and block backends. |
| Start XFCE through upstream Qubes session hooks | Dom0 supplies the window manager; the guest has no greeter, desktop panel or Wayland session. |
| Add upstream's Thunar action fragment to the default configuration | Fedora and Debian do this in their maintainer scripts. Nix generates and validates the same XML at build time. |
| Register upstream session timeout, sudo environment and cron persistence settings | These normally arrive through distribution packages. NixOS installs the same settings declaratively. |
| Keep normal MIME discovery separate from disposable overrides | Qubes applies its XDG override only for selected applications. Installing it globally would redirect ordinary file opening. |
| Provide `qubes.InstallUpdatesGUI` for NixOS | Upstream explicitly supports a distribution-specific implementation. It runs ordinary flake updates and `nixos-rebuild`. |
| Set the update proxy environment for Nix | Both interactive evaluation and daemon downloads need the native UpdatesProxy forwarding socket. |
| Provide one fixed UpdateVM helper path | Dom0 calls `/usr/lib/qubes/qubes-download-dom0-updates.sh`. A tmpfiles link exposes the packaged helper only while this optional role is enabled. |
| Select librepo's upstream RPM verification backend for DNF 5 | The pinned GPGME backend reports missing keys as a generic signature error. DNF then fails before importing the configured repository key. No source or signature-policy change is made. |
| Disable the image builder's KVM requirement | Qubes builders may have no `/dev/kvm`; upstream QEMU TCG can finalize the image. |
| Keep a Cargo lock for the notification package | That upstream release has no lock file. The checked-in dependency resolution makes its Nix build reproducible. |

`pkgs/relocate-paths.py` is a build helper, not a guest startup or repair script.
It performs exact path substitutions with path-boundary checks. It skips binary
files and symlinks. Its audit records are installed under
`share/qubes-nixos/*-paths.json`.

There are no general rewrites from `/usr/bin`, `/usr/sbin`, `/sbin` or
`/usr/lib/qubes` to `/run/current-system/sw`. Required executables are named in
package definitions and checked during the build. Relative assumptions across
package boundaries, such as `qvm-copy` finding qrexec, have explicit checked
substitutions. Wrappers and optional applications are the main runtime lookups.

### Why not add compatibility symlinks?

Store references keep a generation's dependencies together. Installing another
Nix package does not retarget them, and garbage collection preserves references
reachable from that generation. A global compatibility tree adds another shared
namespace and can hide a missing dependency until someone changes the profile.

The drawback is maintenance: upstream scripts can introduce paths the packaging
does not yet know. Build-time executable checks catch missing targets; they do
not prove that every code path works. End-to-end Qubes tests must cover
interpreters, file-copy privilege and device backends. See [test coverage](testing.md).

## Suggested upstream work

These proposals are not applied as patches.

### NixOS image builder: preserve hard links

The pinned image builder populates ext4 with LKL `cptofs`, which copies regular
files separately without retaining their hard-link relationships. Enabling
Nix deduplication before that copy does not preserve the saving in the image.
Preserve hard links in the copy step or provide a native finalisation hook.
The integration keeps the stock builder; installed templates can use
`nix-store --optimise` without changing software or generations.

Sources: [NixOS image builder](https://github.com/NixOS/nixpkgs/blob/5e2305d577ca00acbba631b05cb1094d172b29f3/nixos/lib/make-disk-image.nix),
[LKL copy implementation](https://github.com/lkl/linux/blob/9c51103caa1481493ebbbaf858f016e7f25ab921/tools/lkl/cptofs.c).

### Nixpkgs: RPM runtime and build dependencies

RPM's generated build macros refer to absolute compiler paths. The UpdateVM
helpers need RPM for repository and package handling, but inherit about
301 MiB of compiler dependencies on both pins. Separate RPM's build tools and
compiler-dependent defaults from its query and verification runtime, retaining
the macros DNF needs. The integration keeps the stock package rather than
redirecting compiler commands through PATH or deleting installed files.

Sources: [nixpkgs RPM package](https://github.com/NixOS/nixpkgs/blob/5e2305d577ca00acbba631b05cb1094d172b29f3/pkgs/tools/package-management/rpm/default.nix),
[upstream macro configuration](https://github.com/rpm-software-management/rpm/blob/rpm-4.20.1-release/CMakeLists.txt).

### NixOS: duplicate D-Bus service registration

The pinned NixOS module exposes D-Bus services through both the merged system
profile and individual package directories. D-Bus broker reports duplicate
names at error priority, although the services activate. This is tracked in
[nixpkgs issue 303078](https://github.com/NixOS/nixpkgs/issues/303078) and
[PR 549241](https://github.com/NixOS/nixpkgs/pull/549241), still open when checked
on 2026-10-07. Removing automatic discovery affects other NixOS modules, so this
repository does not copy the pending change or filter the messages.

### Qubes: graphical seat setup on declarative systems

Upstream `qubes-run-xorg` assigns a PC speaker input device to `seat0` using
`loginctl attach`. NixOS blacklists the speaker module by default, leaving no
input device at that path. Loading the stock module makes the device available,
but the command then tries to write a persistent rule in NixOS's read-only
`/etc/udev/rules.d`. Both cases print an error; Xorg and the Qubes GUI agent
continue running.

A suitable upstream interface would allow an already configured graphical seat
or a runtime-only attachment. The integration does not make the udev rules tree
writable or modify the command's behavior. Native GUI, clipboard and input tests
remain separate from this startup diagnostic.

### Qubes/systemd: shutdown of external module mounts

The first shutdown unmount of the externally supplied module filesystem can
fail because udev still maps its index files. Final systemd teardown releases
those mappings and unmounts successfully. This occurs in the tested NixOS,
Fedora and Debian guests. Coordinate the external mount's shutdown lifetime
with udev; keep device handling available until it is no longer needed.

The Qubes GUI agent can also return status 1 during orderly shutdown, including
in the Fedora comparison guest. Upstream should distinguish orderly session
termination from a running-session failure. Treating every status 1 as success
would hide real faults. Neither behavior is patched here.

See [shutdown coverage](testing.md#shutdown). Running-unit checks and complete
shutdown-console checks are separate results.

### DNF and librepo: missing repository keys with GPGME

DNF 5.4.2.1's parallel repository download handling recognizes a missing key by
the RPM backend's `Signing key not found` message. Librepo 1.20.0's GPGME backend
returns `Bad GPG signature` for that case. A fresh signed repository fails before
DNF imports its configured key, even when GnuPG independently verifies the
signature. Use a structured error code shared by both backends. The package
selects the existing RPM backend with `USE_GPGME=OFF` and keeps verification on.

Sources: [DNF error handling](https://github.com/rpm-software-management/dnf5/blob/5.4.2.1/libdnf5/repo/repo_sack.cpp),
[GPGME backend](https://github.com/rpm-software-management/librepo/blob/1.20.0/librepo/gpg_gpgme.c),
[RPM backend](https://github.com/rpm-software-management/librepo/blob/1.20.0/librepo/gpg_rpm.c).

### NixOS: external kernel module locations

`kmod-static-nodes.service` in the pinned NixOS module checks the booted system's
Nix kernel tree even with `boot.kernel.enable = false`. An external kernel uses
`/lib/modules/$(uname -r)` instead. The result was missing static nodes and failed
loop-device use. Make the condition follow the kernel source, or expose an
external module directory option. The current integration only overrides the
unit condition; kmod itself already supports the external directory.

### NixOS: external-initramfs handoff

The stock Qubes initramfs successfully reaches NixOS stage 2 on both pins.
Early stage 2 nevertheless emits API-filesystem warnings around `/proc/cmdline`
and `/dev/fd`. A proper upstream improvement would define and test the mount
contract for `boot.initrd.enable = false`, including a foreign initramfs handoff.
Do not assume that removing all initrds is planned: the deprecated implementation
is scripted stage 1. No custom init shim is added here.

### Qubes: paths as build parameters

Some guest scripts and C sources embed paths despite accepting a prefix for
installation. Use build variables for executable, library, data and interpreter
locations, and generate service/RPC files from those values. Test separate
package prefixes, including a separately packaged qrexec client. This would
replace path substitutions with ordinary build configuration.

Package-owned helpers should have immutable paths; user-selected programs and
extension directories should remain explicit runtime interfaces. A universal
PATH search would change the current trust and dependency assumptions.

### Qubes: central NixOS updater support

The current central updater has distribution-specific package-manager backends
and no NixOS backend. The guest's existing RPC does not register a backend in
that dispatcher. Proper support needs a maintained NixOS backend with a declared
configuration location, input update policy, progress and failure handling.
It must distinguish system generations from per-user profiles and must not
report a failed evaluation as "no updates".

The current integration uses the supported `qubes.InstallUpdatesGUI` RPC,
UpdatesProxy and NotifyUpdates. It does not spoof Fedora, emulate DNF or
intercept arbitrary VMExec commands.

### Qubes: template-repository setup in the GUI

The template manager can consume configured third-party repositories. Adding an
arbitrary repository and verifying its signing identity still requires installing
files in dom0. A native add-repository flow could show the URL, fingerprint,
enabled state and removal controls. It should retain existing RPM verification
and the UpdateVM download boundary. No such GUI patch is included here.

### Qubes and GraphicsMagick: SVG menu icons

`qubes.GetImageRGBA` calls `gm identify` before its SVG branch can invoke
`rsvg-convert`. GraphicsMagick 1.3.47 and 1.3.48 reject single quotes in SVG
attribute values, including the quoted font names in some XFCE icons. The same
files work with Fedora's older 1.3.45. This was reproduced independently of the
packaged Qubes handler.

GraphicsMagick should accept valid CSS font names without weakening its input
validation. Qubes could also avoid requiring two SVG parsers: render SVG with
librsvg first, then inspect the resulting raster image. Any upstream change must
retain the existing size limits and untrusted-image handling. This repository
does not change either parser or the RPC's behavior.

References: [upstream Qubes handler](https://github.com/QubesOS/qubes-core-agent-linux/blob/v4.3.48/qubes-rpc/qubes.GetImageRGBA),
[GraphicsMagick changes](https://graphicsmagick.sourceforge.io/ChangeLog.html).

Architectural rationale and source links are in [WHY.md](../WHY.md).
