# Compared with Debian and Fedora templates

Target: Qubes 4.3. See [tested versions and results](testing.md).

| Feature | This NixOS template | Qubes Debian/Fedora templates |
| --- | --- | --- |
| Template Manager installation | Native RPM; one-time third-party repository setup | Included Qubes repositories |
| Shared TemplateVM root; persistent AppVM home | Native Qubes volumes | Same |
| Disposable qubes, backup and restore | Native Qubes tools | Same |
| Windows and clipboard | Upstream Qubes Xorg agent; standard clipboard shortcuts | Upstream Qubes guest tools |
| File transfer, disposable editing, PDF/image conversion | Upstream Qubes RPCs | Same interfaces |
| Audio, USB, block and input forwarding | Upstream Qubes tools; normal device permissions | Same interfaces |
| Network/firewall and UpdateVM roles | Available; optional NixOS module settings | Available through guest packages |
| Add software to the template | Edit `configuration.nix`; `nixos-rebuild switch` | APT or DNF |
| Configure the system | NixOS modules and flake | Distribution files and tools |
| Upgrade NixOS packages | Pinned flake inputs; rebuild; rollback generations | Distribution repositories and package transactions |
| Qubes central updater | No NixOS backend; use native `InstallUpdatesGUI` RPC or rebuild | Supported |
| Update proxy and update notification | Implemented | Supported |
| AppVM-only Nix package installs | New store objects disappear at restart; install shared software in the TemplateVM | Root package changes also disappear at restart |
| Disk maintenance | Deduplication; collect unreferenced paths under pressure; manually prune old generations | Package caches and distribution cleanup |
| Menu icons | Some upstream GraphicsMagick conversions fail; entries still launch | Distribution icon handling |
| Support scope | Versions and checks listed in the test record | Qubes-supported distribution releases |

No claim of complete parity: the central updater and some menu icons remain
documented gaps. Existing Debian/Fedora AppVMs do not become NixOS AppVMs merely
by changing their template; create a new qube and migrate application data.
