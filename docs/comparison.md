# Compared with Debian and Fedora templates

Target: Qubes 4.3.
[Test coverage](testing.md) | [Missing and untested features](feature-gaps.md).

Confidence: high for the listed implementations and tests.
**Complete feature parity is not claimed.**

- Fedora/Debian: each has XFCE, GNOME and minimal; six official profiles.
- NixOS: stable/unstable XFCE and stable/unstable minimal; four profiles.

[Official template list](https://doc.qubes-os.org/en/r4.3/user/templates/templates.html#official).

| Feature | This NixOS template | Qubes Debian/Fedora templates |
| --- | --- | --- |
| Template Manager installation | Native RPM; one-time third-party repository setup | Included Qubes repositories |
| Shared TemplateVM root; persistent AppVM home | Native Qubes volumes | Same |
| Disposable qubes, backup and restore | Native Qubes tools | Same |
| Windows and clipboard | Upstream Qubes Xorg agent; standard clipboard shortcuts | Upstream Qubes guest tools |
| File transfer, disposable editing, PDF/image conversion | Upstream Qubes RPCs | Same interfaces |
| Audio, USB, block and input forwarding | Upstream Qubes tools; normal device permissions | Same interfaces |
| Network/firewall and UpdateVM roles | Available; optional NixOS module settings | Available through guest packages |
| Add software to the template | Edit its profile selection; `nixos-rebuild switch` | APT or DNF |
| Configure the system | NixOS modules and flake | Distribution files and tools |
| Minimal profiles | Xorg/xterm, root qrexec administration, optional roles | Official minimal templates with optional guest packages |
| Upgrade NixOS packages | Pinned flake inputs; rebuild; rollback generations | Distribution repositories and package transactions |
| Qubes central updater | No NixOS backend; use the headless guest update service, XFCE update RPC or rebuild | Supported |
| Update proxy and update notification | Implemented | Supported |
| AppVM-only Nix package installs | New store objects disappear at restart; install shared software in the TemplateVM | Root package changes also disappear at restart |
| Disk maintenance | Deduplication; collect unreferenced paths under pressure; manually prune old generations | Package caches and distribution cleanup |
| Menu icons | Some upstream GraphicsMagick conversions fail; entries still launch | Distribution icon handling |
| CTAP, Salt-managed guests, GUIVM/AudioVM provider roles | Missing project integration; see the inventory | Separate Qubes guest packages and documented setups |
| Support scope | Versions and checks listed in the test record | Qubes-supported distribution releases |

**Moving from Debian/Fedora:** create a NixOS qube and migrate application data.
Changing an existing qube's template does not migrate distribution-specific settings.

## Commands and workflow

Run guest package/configuration commands as root in the TemplateVM:

- XFCE: `sudo -i`.
- Minimal: run `qvm-run -u root TEMPLATE xterm` in dom0.

For NixOS, replace `CONFIG` with `nixos`, `nixos-unstable`, `nixos-minimal` or
`nixos-unstable-minimal`. Edit `configuration.nix` for XFCE or
`configuration-minimal.nix` for minimal, both under `/etc/nixos`.

| Task | NixOS | Debian | Fedora |
| --- | --- | --- | --- |
| Install `htop` | Add `pkgs.htop` to the existing `environment.systemPackages` list, then rebuild | `apt install htop` | `dnf install htop` |
| Remove `htop` | Remove that list entry, then rebuild | `apt remove htop` | `dnf remove htop` |
| Apply system configuration | `nixos-rebuild switch --flake /etc/nixos#CONFIG` | Edit the service's configuration; reload/restart it as documented | Edit the service's configuration; reload/restart it as documented |
| Update packages | `systemctl start qubes-nixos-update.service` | Qubes Update, or `qubes-vm-update --targets TEMPLATE` in dom0 | Qubes Update, or `qubes-vm-update --targets TEMPLATE` in dom0 |
| Roll back the system generation | `nixos-rebuild switch --rollback --no-reexec` | No equivalent whole-system generation; restore a backup or follow package-specific recovery | No equivalent whole-system generation; restore a backup or follow package-specific recovery |

Package commands: [Qubes installation guide][install], [APT][apt], [DNF][dnf].

**Updates:** use [Qubes Update][updates] for Debian/Fedora. Its NixOS backend is
missing. The NixOS service refreshes selected flake inputs and rebuilds;
it does not update this project's integration files.
[Routine and integration updates](updates.md).

- NixOS: edit the desired package/service configuration, build, then activate.
  Keep `/etc/nixos` in version control. A rollback restores a retained system
  generation, not edited source files or application data.
- Debian/Fedora: install/remove packages with APT/DNF; configure services using
  their normal files and tools. Use Qubes Update for routine updates.
- All three: shut down the TemplateVM after changes, then restart its AppVMs.
  Work in the AppVMs; their home directories remain separate. Newly installed
  system packages in an AppVM disappear when its root resets. Nix profiles in
  home can then refer to missing store paths. See [persistence][templates].

## Different configurations

- Different persistent system package sets or NixOS configurations normally
  need separate TemplateVMs. Clone a template for each shared configuration.
- Per-user application settings in home, Qubes firewall rules and device
  permissions can differ between AppVMs using the same template.
- If many qubes each need their own persistent system configuration, consider
  [StandaloneVMs][standalones]. Each keeps its own root and must be updated
  separately; it loses the shared-template storage and maintenance savings.
  The NixOS standalone workflow is [not yet tested](feature-gaps.md).

[install]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-install-software.html
[apt]: https://manpages.debian.org/trixie/apt/apt.8.en.html
[dnf]: https://dnf5.readthedocs.io/en/latest/commands/remove.8.html
[updates]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-update.html
[templates]: https://doc.qubes-os.org/en/r4.3/user/templates/templates.html#inheritance-and-persistence
[standalones]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/standalones-and-hvms.html
