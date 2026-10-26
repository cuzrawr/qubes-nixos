# Adaptations and upstream proposals

- Compatibility changes and workarounds, including their maintenance cost.
- No Qubes program-logic, protocol or dom0 patches. Path/shebang adaptations
  and native configuration remain explicit below.
- Confidence: high for inspected code and [recorded tests](testing.md);
  proposed upstream solutions are recommendations, not completed fixes.

## What is changed

| Change | Reason and cost |
| --- | --- |
| Bind named commands to store paths | Qubes uses FHS paths. Nix must retain each dependency explicitly. A new upstream path can need packaging changes. |
| Use `/etc/zoneinfo` for Qubes' timezone link | NixOS timedated recognizes this catalog path. Qubes still selects the timezone. |
| Materialize the X11 font directory | Native `fonts.fontDir.decompressFonts` avoids unreadable symlinked core fonts. Adds about 26-41 MB, depending on the pin. |
| Fix shebangs and Python wrappers | Interpreters and imported modules must be present outside a distribution-wide Python environment. |
| Relocate each package's own installed paths | Upstream scripts expect a shared `/usr`. The helper only maps files actually installed by that package, plus explicit mappings. |
| Use system-profile paths for application discovery and extensions | These deliberately follow the active configuration. They cannot be fixed to one application's output. |
| Expose `qfile-unpacker` through NixOS security wrappers | The store cannot supply its setuid privilege. The underlying executable remains mode 0755. |
| Register upstream services, udev rules and tmpfiles in NixOS | A package install does not run Fedora presets or Debian maintainer scripts. Upstream ordering is retained except for the resize unit below. |
| Replace the early resize unit's schedule | Run the unchanged helper after local network setup, before qrexec. Fixes the reproduced udev/network cycle. Maintain one small declarative service definition. |
| Restart qrexec after activation | NixOS user services need the transport during activation. `stopIfChanged = false` avoids stopping it before they restart. |
| Run the upstream post-install hook after generation changes | Refresh application menus and guest features, like the upstream DNF transaction hook. A NixOS oneshot service tracks the system profile. |
| Set the static-device-node condition to `/lib/modules` | The kernel and modules are supplied by Qubes, not a NixOS kernel closure. Normal kmod/tmpfiles then create nodes such as `loop-control`. |
| Merge upstream Xen helper directories | Xen, the core agent and Linux utilities each install helpers used by network and block backends. |
| Register Xen's packaged `xl.conf` | The native device daemon reads `/etc/xen/xl.conf`. Install the unchanged default through NixOS, alongside the helper directory. |
| Start XFCE through upstream Qubes session hooks | Dom0 supplies the window manager; the guest has no greeter, desktop panel or Wayland session. |
| Pass NixOS's indexed fonts to Qubes' Xorg config | Qubes selects its own main config, so NixOS's generated font paths would otherwise be unused. Use `fonts.fontDir` and the native Xorg Files section. |
| Add upstream's Thunar action fragment to the default configuration | Fedora and Debian do this in their maintainer scripts. Nix generates and validates the same XML at build time. |
| Register upstream session timeout, sudo environment and cron persistence settings | These normally arrive through distribution packages. NixOS installs the same settings declaratively. |
| Keep normal MIME discovery separate from disposable overrides | Qubes applies its XDG override only for selected applications. Installing it globally would redirect ordinary file opening. |
| Provide `qubes.InstallUpdatesGUI` for NixOS | Upstream explicitly supports a distribution-specific implementation. It runs ordinary flake updates and `nixos-rebuild`. |
| Separate GUI/audio and privilege selections | Minimal shares the same guest tools but omits optional roles and passwordless root. Full XFCE defaults remain. Headless updates use the existing systemd job through root qrexec. |
| Separate GUI and audio package outputs | Use upstream's `install-pipewire` target for the optional audio module, settings and feature announcement. Minimal explicitly disables native PipeWire unless this role is enabled. |
| Set the update proxy environment for Nix | Both interactive evaluation and daemon downloads need the native UpdatesProxy forwarding socket. |
| Provide one fixed UpdateVM helper path | Dom0 calls `/usr/lib/qubes/qubes-download-dom0-updates.sh`. A tmpfiles link exposes the packaged helper only while this optional role is enabled. |
| Select librepo's upstream RPM verification backend for DNF 5 | The pinned GPGME backend reports missing keys as a generic signature error. DNF then fails before importing the configured repository key. No source or signature-policy change is made. |
| Disable the image builder's KVM requirement | Qubes builders may have no `/dev/kvm`; upstream QEMU TCG can finalize the image. |
| Keep a Cargo lock for the notification package | That upstream release has no lock file. The checked-in lock fixes Rust dependency versions and checksums. |

- `pkgs/relocate-paths.py` runs at build time. Exact substitutions with path
  boundaries; skips binaries and symlinks. Audit records:
  `share/qubes-nixos/*-paths.json`.
- Required executables have named dependencies and build checks. Cross-package
  assumptions, such as `qvm-copy` locating qrexec, have checked substitutions.
- Wrappers, selected applications and extension directories remain runtime
  lookups. No directory-wide rewrite to `/run/current-system/sw`.

### Why not add compatibility symlinks?

| Store references | Global compatibility tree |
| --- | --- |
| Retain each generation's dependencies | Adds a shared namespace tied to installed packages |
| Another package cannot retarget them | Profile changes can expose a missing or conflicting dependency |
| GC preserves referenced paths | Requires separate lifetime management |

Cost: upstream can introduce new paths. Executable checks catch missing targets,
not every runtime branch. Test interpreters, file-copy privilege and device
backends on Qubes. [Coverage](testing.md).

## Suggested upstream work

These proposals are not applied as patches.

### Qubes: root resize and blocking network udev jobs

- Reproduced: pending root growth plus a NetVM can block qrexec startup.
- Cause: early resize waits for udev; a synchronous network udev job waits for
  a service that needs normal initialization; initialization waits for resize.
- Raising qrexec's timeout did not repair this case: `udevadm settle` timed out
  after 120 seconds, leaving the filesystem smaller than the volume.
- Upstream candidate: queue network service work asynchronously through a
  supported udev/systemd interface, with hotplug and removal tests.
- Current integration: unchanged helper in a later NixOS service. No udev-rule
  patch, custom resize program or disk-layout conversion.
- [Decision and alternatives](../WHY.md#root-resize-ordering),
  [configuration](configuration.md#boot-and-service-ordering),
  [user procedure](resizing.md), [regression results](testing.md).

Sources: [Qubes issue 4419](https://github.com/QubesOS/qubes-issues/issues/4419),
[upstream udev rule](https://github.com/QubesOS/qubes-core-agent-linux/blob/v4.3.48/network/udev-qubes-network.rules),
[resize helper](https://github.com/QubesOS/qubes-core-agent-linux/blob/v4.3.48/qubes-rpc/resize-rootfs).

### NixOS image builder: preserve hard links

- Observed: LKL `cptofs` copies regular files without preserving hard links.
  Deduplication before this step does not reduce the resulting image.
- Upstream: preserve hard links or provide a native finalization hook.
- Current: stock builder; `nix-store --optimise` after installation retains
  software and rollback generations.

Sources: [NixOS image builder](https://github.com/NixOS/nixpkgs/blob/5e2305d577ca00acbba631b05cb1094d172b29f3/nixos/lib/make-disk-image.nix),
[LKL copy implementation](https://github.com/lkl/linux/blob/9c51103caa1481493ebbbaf858f016e7f25ab921/tools/lkl/cptofs.c).

### Nixpkgs: RPM runtime and build dependencies

- Observed: RPM build macros reference compilers; UpdateVM inherits about
  301 MiB of compiler dependencies on both pins.
- Upstream: separate build tools/compiler defaults from query/verification
  runtime while retaining macros DNF needs.
- Current: stock package. No deleted files or compiler redirection through PATH.

Sources: [nixpkgs package](https://github.com/NixOS/nixpkgs/blob/5e2305d577ca00acbba631b05cb1094d172b29f3/pkgs/tools/package-management/rpm/default.nix),
[upstream macros](https://github.com/rpm-software-management/rpm/blob/rpm-4.20.1-release/CMakeLists.txt).

### NixOS: duplicate D-Bus service registration

- Cause: services appear through both the merged profile and individual package
  directories. D-Bus broker reports duplicate names; services still activate.
- Tracked by [issue 303078](https://github.com/NixOS/nixpkgs/issues/303078) and
  [PR 549241](https://github.com/NixOS/nixpkgs/pull/549241), both open on 2026-10-15.
- Current: retain automatic discovery. Removing it affects other NixOS modules;
  no copied patch or message filtering.

### Qubes: graphical seat setup on declarative systems

- Upstream `qubes-run-xorg` uses `loginctl attach` for a PC speaker input device.
- NixOS normally blacklists that module, so the path is absent. Loading it makes
  `loginctl` try to write a persistent rule into read-only `/etc/udev/rules.d`.
- Both cases emit an error; the tested Xorg/GUI session continues.
- Upstream: accept an already configured seat or runtime-only attachment.
- Current: no writable udev-rule tree or command patch. GUI, clipboard and input
  tests remain separate from this diagnostic.

### Qubes/systemd: shutdown of external module mounts

- Observed in NixOS, Fedora and Debian: the first external-module unmount can
  fail while udev maps module indexes; final teardown releases them and succeeds.
- Upstream: coordinate mount lifetime with udev without stopping device handling
  too early.
- Qubes GUI agent sometimes returns status 1 during orderly shutdown, also seen
  in Fedora. Distinguish session termination from running-session failure.
- Current: neither behavior patched; status 1 is not globally treated as success.
  [Shutdown coverage](testing.md#shutdown).

### systemd: inherited I/O-pressure threshold

- Observed on the unstable pin, systemd 261.2: `Failed to adjust io pressure
  threshold, ignoring: Device or resource busy`.
- Cause: the user manager inherits an I/O-pressure watch and its threshold.
  `sd-event` locks inherited settings; the manager's subsequent setter returns
  `EBUSY`, including when the requested threshold is unchanged.
- Verified: the running user manager's I/O-pressure descriptor remains
  registered with epoll. A reproducer using the guest's libsystemd, as the
  ordinary user, returns `EBUSY` and retains an enabled, registered watch.
- Confidence: high for the warning's cause and retained registration. This
  check does not measure pressure-event latency or storage performance.
- Upstream candidate: avoid overriding an inherited watch, or handle that
  rejected override without reporting a monitoring failure.
- Current: monitoring and diagnostics remain enabled; no systemd patch.

Sources: [manager setup](https://github.com/systemd/systemd/blob/v261.2/src/core/manager.c#L819-L841),
[inherited watch](https://github.com/systemd/systemd/blob/v261.2/src/libsystemd/sd-event/sd-event.c#L1969-L1990),
[threshold setter](https://github.com/systemd/systemd/blob/v261.2/src/libsystemd/sd-event/sd-event.c#L5461-L5477).

### Qubes/Linux: duplicate memory onlining

- Observed on NixOS and stock Fedora: `50-qubes-mem-hotplug.rules` reports
  `Invalid argument` while writing `online` to a memory block.
- Verified on Qubes kernel 6.18.31: kernel tracing shows `xen-balloon`
  successfully onlining memory, followed by udev's `device_online()` returning
  1 (already online). The memory sysfs handler converts that result to `EINVAL`.
- The upstream rule already checks for `offline`. Kernel auto-online can
  complete between that check and the write; another offline check alone
  would not remove the race.
- Test: 768 MiB allocation completed; all exposed blocks online; zero failed
  units. Fresh Fedora reproduced the warning during a 640 MiB allocation.
  Debian completed its allocation without the warning.
- Confidence: high for this traced case. An offline block, OOM or failed
  allocation needs a separate investigation; do not dismiss every hotplug error.
- Upstream candidate: coordinate kernel auto-online and the udev fallback,
  retaining support for kernels without auto-online.
- Current: unchanged upstream rule and kernel policy; no warning suppression.

Sources: [Qubes rule](https://github.com/QubesOS/qubes-core-agent-linux/blob/v4.3.48/misc/50-qubes-mem-hotplug.rules),
[online result](https://github.com/torvalds/linux/blob/v6.18/drivers/base/core.c#L4218-L4236),
[memory state write](https://github.com/torvalds/linux/blob/v6.18/drivers/base/memory.c#L416-L452),
[kernel auto-online](https://github.com/torvalds/linux/blob/v6.18/mm/memory_hotplug.c#L1591-L1593).

### DNF and librepo: missing repository keys with GPGME

- DNF 5.4.2.1 recognizes the RPM backend's missing-key error. Librepo 1.20.0's
  GPGME backend returns a generic bad-signature error, preventing key import.
- Reproduced with a fresh signed repository and independent GnuPG verification.
- Upstream: use a shared structured error code.
- Current: `USE_GPGME=OFF` selects the existing RPM backend; verification stays on.

Sources: [DNF handling](https://github.com/rpm-software-management/dnf5/blob/5.4.2.1/libdnf5/repo/repo_sack.cpp),
[GPGME backend](https://github.com/rpm-software-management/librepo/blob/1.20.0/librepo/gpg_gpgme.c),
[RPM backend](https://github.com/rpm-software-management/librepo/blob/1.20.0/librepo/gpg_rpm.c).

### NixOS: external kernel module locations

- The pinned `kmod-static-nodes` condition checks a Nix kernel tree even with
  `boot.kernel.enable = false`; external modules are in `/lib/modules/$(uname -r)`.
- Result: missing static nodes and failed loop-device use.
- Upstream: make the condition follow the kernel source or expose an external
  module-directory option.
- Current: override only the unit condition; kmod already supports this directory.

### NixOS: external-initramfs handoff

- Both pins reach stage 2 through Qubes' initramfs, with early API-filesystem
  warnings around `/proc/cmdline` and `/dev/fd`.
- Upstream: define/test the mount contract for `boot.initrd.enable = false` and
  foreign-initramfs handoff.
- Current: no init shim. Scripted stage 1 is deprecated, not all initramfs support.

### Qubes: paths as build parameters

- Some scripts/C sources embed paths despite accepting installation prefixes.
- Upstream: build variables for executables, libraries, data and interpreters;
  generate service/RPC files; test separate prefixes and qrexec packaging.
- Keep required helpers immutable and selected programs/extensions explicit.
  Universal PATH lookup changes dependency and trust assumptions.
- Current: checked path/shebang substitutions, with recorded runtime tests.

### Qubes: central NixOS updater support

- No NixOS backend in the central distribution dispatcher. Guest RPC support
  does not register one.
- Upstream backend needs configuration location, input policy, progress and
  failure handling; distinguish system generations from per-user profiles.
  Failed evaluation must not mean "no updates".
- Current: supported `qubes.InstallUpdatesGUI`, UpdatesProxy, NotifyUpdates and
  headless root-qrexec service invocation. No Fedora identity or VMExec interception.

### Qubes: template-repository setup in the GUI

- Template Manager consumes configured third-party repositories; adding one
  and verifying its key still requires files in dom0.
- Upstream: repository URL, fingerprint, enable/disable and removal controls.
  Retain RPM verification and the UpdateVM download boundary.
- Current: documented one-time setup; no GUI patch.

### Qubes and GraphicsMagick: SVG menu icons

- `qubes.GetImageRGBA` runs `gm identify` before its SVG branch invokes librsvg.
- GraphicsMagick 1.3.47/1.3.48 reject single quotes in some SVG attributes,
  including XFCE font names. The same files work with 1.3.45; reproduced
  independently of the packaged handler.
- Upstream: support valid CSS names, or render SVG with librsvg before raster
  inspection. Preserve size limits and untrusted-image handling.
- Current: neither parser nor RPC patched; some menu icons remain missing.

Sources: [Qubes handler](https://github.com/QubesOS/qubes-core-agent-linux/blob/v4.3.48/qubes-rpc/qubes.GetImageRGBA),
[GraphicsMagick changes](https://graphicsmagick.sourceforge.io/ChangeLog.html).

Architectural rationale and source links are in [WHY.md](../WHY.md).
