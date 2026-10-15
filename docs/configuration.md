# Configuration reference

Edit `/etc/nixos/configuration.nix` for XFCE or `configuration-minimal.nix`
for minimal. Rebuild with the matching configuration name in the README.
Native Qubes policies and qube properties remain in dom0.

## Optional components

| Option | XFCE | Minimal | Purpose |
| --- | --- | --- | --- |
| `services.qubes.desktop.enable` | `true` | `false` | XFCE applications, Firefox default, converters and Thunar actions; enables GUI |
| `services.qubes.gui.enable` | `true` | `true` | Qubes Xorg session, clipboard, xterm and notifications |
| `services.qubes.audio.enable` | `true` | `false` | PipeWire audio client; defaults to the desktop option |
| `services.qubes.passwordlessRoot.enable` | `true` | `false` | Passwordless sudo/su and polkit administration inside the qube |
| `programs.firefox.enable` | `true` | `false` | Firefox from the desktop module; independent of the application list |
| `services.qubes.usb.enable` | `true` | `false` | Native USB attachment/export and input forwarding |
| `services.qubes.splitGpg.enable` | `true` | `false` | Split GPG 2; disabling does not delete dom0 policies |
| `services.qubes.updateVM.enable` | `true` | `false` | Template/dom0 downloads, DNF/RPM and fixed helper entry point |
| `services.qubes.updates.enable` | `true` | `true` | NixOS update service, proxy environment and notifications |
| `networking.networkmanager.enable` | `true` | `false` | Physical interfaces; Qubes' Xen uplink still uses QubesDB |

These are shipped profile selections, not all module-level defaults.
For a headless custom profile, disable both `desktop.enable` and `gui.enable`;
remove unwanted applications from its package list. Headless role coverage is
listed in [testing](testing.md).

Installed tools do not grant cross-qube access:

- UpdateVM: select an AppVM in Qubes Global Settings. Separate from NixOS updates.
- Network provider: use normal Qubes NetVM properties and services.
- NetworkManager: starts only with the native `network-manager` qube service.
- Split GPG 2: configure `split-gpg2-client`, server keys and dom0 policy using
  [upstream instructions](https://doc.qubes-os.org/en/r4.3/user/security-in-qubes/split-gpg-2.html).
- USB, microphone and file access: normal Qubes device permissions/RPC policies.

## Boot and service ordering

Non-default settings are declarative. Edit Nix modules, then rebuild; do not
edit generated files under `/etc/systemd/system`.

| Setting | Why it differs |
| --- | --- |
| `boot.kernel.enable = false`, `boot.initrd.enable = false` | Qubes supplies both; NixOS enters through its stage-2 init script |
| `kmod-static-nodes` condition | Reads the Qubes-provided `/lib/modules`, not a NixOS-built kernel tree |
| `qubes-rootfs-resize.enable = false` | Disables the upstream early-boot schedule, which can deadlock with network udev jobs |
| `qubes-nixos-rootfs-resize` | Same upstream helper, normal service dependencies, after `network.target`, before qrexec |
| `qubes-qrexec-agent.stopIfChanged = false` | Keeps qrexec available while dependent services restart during a rebuild |
| `qubes-nixos-update` restart/stop settings | Prevents an update from stopping its own systemd job during activation |
| `fonts.fontDir.enable = true` | Supplies indexed fonts to Qubes' Xorg config. `UseDefaultFontPath = false` avoids appending nonexistent compiled-in directories; native `fontPath`, `filesSection` and `serverFlagsSection` remain configurable |

Resize order in 0.1.1:

```text
normal local filesystem initialization
  -> local network setup (no Internet wait)
  -> qubes-nixos-rootfs-resize
  -> qubes-qrexec-agent
```

- Keep the original resize unit disabled while its replacement is enabled.
- Do not move the replacement before `local-fs.target`, or disable its normal
  dependencies. That recreates the diagnosed boot cycle.
- `After=` controls order; it does not require an Internet connection.
- Private-volume initialization and bind mounts keep their upstream ordering.
- A failed resize remains a failed unit. No exit code is suppressed.
- Inspect with `systemctl cat qubes-nixos-rootfs-resize` and
  `systemctl show qubes-nixos-rootfs-resize -p Before -p After`.
- Implementation: [persistence.nix](../modules/persistence.nix).
  Reason and alternatives: [WHY.md](../WHY.md#root-resize-ordering).
  User procedure: [resizing](resizing.md).

## Settings that can break assumptions

| Setting | Required behavior / consequence |
| --- | --- |
| `services.qubes.enable` | Keep enabled; disabling removes the boot/guest integration |
| `boot.kernel.enable`, `boot.initrd.enable` | Keep `false`; dom0 provides the kernel, initramfs and matching modules |
| Qubes `kernel` and `virt_mode` properties | Use a Qubes-provided VM kernel and PVH; booting a kernel from the guest is not configured |
| Extra kernel modules / guest kernel settings | Nix-built modules may not match the Qubes kernel; select/update the kernel through Qubes and use its matching modules |
| Root filesystem and `/rw` devices | Qubes supplies `dmroot` and `xvdb`; do not replace with host block devices |
| `/nix` persistence | Keep on template root; a shared writable or home-backed store changes isolation and rollback behavior |
| Secrets in flake sources or Nix values | Can enter the world-readable store and shared template root; keep secrets outside build inputs |
| `system.stateVersion` | Keep the original `26.05`; it controls compatibility defaults, not the selected release |
| User `user`, UID 1000 | Matches the default guest account; changing it requires matching Qubes default-user and ownership settings |
| Guest passwords/sudo/polkit | XFCE permits local passwordless administration; minimal disables it and locks root's password. Root qrexec from dom0 remains the administration interface |
| NixOS firewall/networkd/resolvconf | Qubes manages the Xen uplink and firewall; a second configurator can overwrite routes or rules |
| `services.qubes.updates.directory` | Writable flake directory; default `/etc/nixos` |
| `services.qubes.updates.configuration` | Must name an existing `nixosConfigurations` entry; custom names are supported |
| `services.qubes.updates.inputs` | Chooses inputs refreshed by the update RPC/checker; empty means all inputs |
| Binary caches and trusted public keys | Changes whose prebuilt code Nix accepts; review before adding |
| `nix.settings.trusted-users` | Grants powerful Nix daemon capabilities; not needed for ordinary package use |

## Space and Nix behavior

| Action / setting | Result |
| --- | --- |
| `nix flake update` | Changes the lock file and downloads inputs; does not activate a system |
| `nixos-rebuild build` | Builds a generation; does not switch running services |
| `nixos-rebuild test` | Activates for testing; does not select it as the next boot generation |
| `nixos-rebuild switch` | Builds, activates and selects the generation for later boots |
| `nix shell` or `nix run` in an AppVM | Works for temporary use; newly downloaded store objects disappear when its root resets |
| Failed evaluation/build | Previous running generation remains; downloaded objects may remain until GC |
| Failed service activation | Can leave partially changed running services; inspect errors and roll back |
| Rollback | Restores a retained generation; does not revert source edits or application data |
| Package removed from configuration | Removed from the new profile; old generations can still retain it |
| Store GC | Deletes unreferenced store objects, not arbitrary home files |
| Delete old generations | Removes rollback choices and permits collecting their exclusive dependencies |
| `result-*` symlinks | Keep build outputs alive until removed |
| Qubes volume resize | Raises guest capacity; does not increase free space in dom0's storage pool |
| Automatic cleanup thresholds | 1 GiB minimum, 3 GiB target; cannot free live generations or guarantee a large build fits |
| `auto-optimise-store` | Hard-links identical store files; does not delete generations |
| `nix-store --optimise` | Deduplicates existing files, including those copied into the initial image; does not remove software or rollback choices |
| Documentation/voice selection | Manual pages and one MBROLA voice per language retained; shared defaults in `profiles/base.nix` |

Update large package sets with sufficient root space and RAM. Prefer cached
builds; source builds of large applications can need much more than ordinary
desktop use. Use Qubes Settings to grow the template's root volume or memory.

Run maintenance in the TemplateVM, then shut it down and restart dependent
AppVMs. Store optimisation can take several minutes. In an AppVM, the saving
is lost when its root resets. Filesystem savings, compressed RPM size and dom0
pool usage are different measurements; retained Qubes volume revisions can
still occupy space.
