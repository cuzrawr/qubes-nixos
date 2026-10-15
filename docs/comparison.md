# Compared with Debian and Fedora templates

Target: Qubes 4.3. See [tested versions and results](testing.md) and the
[missing/untested feature inventory](feature-gaps.md). Shared upstream
interfaces do not establish complete feature parity.

Official Fedora and Debian each provide XFCE, GNOME and minimal profiles: six
in total. This project provides four NixOS profiles: stable/unstable XFCE and
stable/unstable minimal. [Official template list](https://doc.qubes-os.org/en/r4.3/user/templates/templates.html#official).

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
| Minimal profiles | Xorg/xterm, root qrexec administration, optional roles; 0.1.1 acceptance pending | Official minimal templates with optional guest packages |
| Upgrade NixOS packages | Pinned flake inputs; rebuild; rollback generations | Distribution repositories and package transactions |
| Qubes central updater | No NixOS backend; use the headless guest update service, XFCE update RPC or rebuild | Supported |
| Update proxy and update notification | Implemented | Supported |
| AppVM-only Nix package installs | New store objects disappear at restart; install shared software in the TemplateVM | Root package changes also disappear at restart |
| Disk maintenance | Deduplication; collect unreferenced paths under pressure; manually prune old generations | Package caches and distribution cleanup |
| Menu icons | Some upstream GraphicsMagick conversions fail; entries still launch | Distribution icon handling |
| CTAP, Salt-managed guests, GUIVM/AudioVM provider roles | Missing project integration; see the inventory | Separate Qubes guest packages and documented setups |
| Support scope | Versions and checks listed in the test record | Qubes-supported distribution releases |

For Debian/Fedora AppVMs, create a new NixOS qube and migrate application data.
Changing the template alone does not migrate distribution-specific settings.
