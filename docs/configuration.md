# Configuration reference

Edit `/etc/nixos/configuration.nix`; rebuild with the version's configuration
name from the README. Native Qubes policies and qube properties remain in dom0.

## Optional components

| Option | Default template | Effect when disabled |
| --- | --- | --- |
| `services.qubes.desktop.enable` | `true` | Removes the Qubes Xorg/XFCE session; also remove unwanted apps from `environment.systemPackages` for a smaller headless template |
| `programs.firefox.enable` | `true` | Removes the module-provided Firefox package |
| `services.qubes.usb.enable` | `true` | Removes native USB attachment/export and input forwarding tools |
| `services.qubes.splitGpg.enable` | `true` | Removes Split GPG 2; existing dom0 policies are not deleted |
| `services.qubes.updateVM.enable` | `true` | Removes template/dom0 download RPCs, DNF/RPM dependencies and the fixed dom0-update helper link |
| `services.qubes.updates.enable` | `true` | Removes NixOS update automation and its proxy environment; configure updates yourself |
| `networking.networkmanager.enable` | `true` | Removes physical-interface management; Qubes' Xen uplink still uses QubesDB |

Installed tools do not grant cross-qube access:

- UpdateVM: select an AppVM in Qubes Global Settings. Separate from NixOS updates.
- Network provider: use normal Qubes NetVM properties and services.
- NetworkManager: starts only with the native `network-manager` qube service.
- Split GPG 2: configure `split-gpg2-client`, server keys and dom0 policy using
  [upstream instructions](https://doc.qubes-os.org/en/r4.3/user/security-in-qubes/split-gpg-2.html).
- USB, microphone and file access: normal Qubes device permissions/RPC policies.

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
| Guest passwords/sudo/polkit | Standard Qubes model: the desktop user administers its own qube; isolation is between qubes |
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
| Automatic cleanup thresholds | 1 GiB minimum, 3 GiB target; cannot free live generations or guarantee a large build fits |
| `auto-optimise-store` | Hard-links identical store files; does not delete generations |
| Documentation/voice selection | Manual pages and one MBROLA voice per language retained; editable in `configuration.nix` |

Update large package sets with sufficient root space and RAM. Prefer cached
builds; source builds of large applications can need much more than ordinary
desktop use. Use Qubes Settings to grow the template's root volume or memory.
