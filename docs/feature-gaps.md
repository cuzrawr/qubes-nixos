# Feature gaps and untested cases

Review: 2026-10-15. Target: Qubes 4.3, stock external kernel.

- Scope: [Qubes documentation index][index], linked feature guides, selected
  forum guides, package definitions and recorded tests. Not every forum thread.
- **Missing**: no project package/module or supported setup for the feature.
- **Untested**: no recorded end-to-end result; does not mean it cannot work.
- **Partial**: some checks passed; the missing cases are listed below.
- Confidence: high in code presence/absence and recorded coverage. No support
  claim for untested cases. Historical results apply to v0.1.0 XFCE unless the
  [test record](testing.md) explicitly names another version/profile.

## Missing integration

| Feature | Gap | Source |
| --- | --- | --- |
| CTAP proxy / browser FIDO2 | No `qubes-ctap` package or service integration. USB storage testing does not test CTAP | [CTAP proxy][ctap] |
| Central Qubes updater | No upstream NixOS backend. Use the guest update service or `nixos-rebuild` | [Updates][updates] |
| Salt management of NixOS guests | No Qubes Salt connector/backend; no supported NixOS management disposable | [Salt][salt] |
| Dom0 firmware downloads through NixOS UpdateVM | No `fwupd-qubes-vm` integration; template/dom0 RPM downloads do not cover firmware updates | [Firmware updates][updates] |
| NixOS as GUI domain | No GUI daemon/admin stack or supported `sys-gui` profile. The guest Xorg agent is a different role | [GUI domain][guivm] |
| NixOS as AudioVM | No audio daemon/provider profile. Guest PipeWire transport is implemented | [AudioVM guide][audiovm] |
| Split GPG 1 | Not packaged; use the implemented Split GPG 2 integration | [Split GPG 1][gpg1] |
| Snap helper, Thunderbird integration, idle shutdown | No project packages for `qubes-snapd-helper`, `thunderbird-qubes` or `qubes-app-shutdown-idle` | [Optional guest packages][minimal] |
| Contributed guest packages | RPM/APT repository instructions do not install NixOS guest packages. Each component needs Nix packaging and tests | [Contributed packages][contrib] |
| Guest-provided kernel/initrd, HVM boot | No shipped profile; external Qubes PVH kernel only | [Kernel management][kernels] |

## Partial coverage

| Area | Tested | Still untested |
| --- | --- | --- |
| [Storage growth][resize] | Small root/private growth on v0.1.0; stable networked root-cycle reproduction and ordering fix in 0.1.1 work | All final 0.1.1 artifacts, extreme volume sizes, interrupted growth, every Qubes storage backend |
| [USB and input][usb] | Mass storage, read-only access, synthetic input forwarding | Physical keyboard/mouse through a NixOS USB qube; FIDO, smartcards, cameras, scanners, Bluetooth and other device classes |
| [Block devices][block] | Read-only attachment/export | Writable removable media, device removal during writes, optical media |
| [Networking][network] | IPv4 DNS/HTTPS, NetVM forwarding, firewall deny/recovery, update proxy | IPv6, custom addressing/DNS, VPN and kill-switch configurations, physical Wi-Fi, MAC randomization |
| [Audio][audio] | Synthetic playback/capture and microphone permission/revocation | Physical speakers/microphones, USB/Bluetooth headsets, non-dom0 AudioVM, reconnect and latency/load tests |
| [GUI][gui] | Xorg windows, application launch, menus, notifications, clipboard | Multiple monitors, HiDPI, fullscreen variations, live monitor changes, non-dom0 GuiVM, accessibility and non-US input methods |
| [Files and disposables][disposable] | Copying, editing round trip, isolation, PNG/PDF conversion | Large/hostile-file stress, interrupted transfers, alternate disposable customizations |
| [Persistence][persist] | Home, `/usr/local`, root reset and generation propagation | Full `custom-persist` matrix, unusual bind targets, conflicts with NixOS-generated `/etc` symlinks |
| [Backup and restore][backup] | Encrypted native backup/restore with private data | Cross-host migration, recovery after host-storage failure, very large backups |
| [Power management][suspend] | Guest suspend/resume preparation RPCs | Physical host suspend/resume with NixOS clients and device providers |
| [Memory management][memory] | Repeated/paired starts; controlled allocation; kernel trace of the duplicate-online warning | Long pressure stress, swap exhaustion, all balloon/hotplug transitions |
| Nix updates and rollback | v0.1.0 GUI updates, failed builds, rollback and generation retention | Final 0.1.1 upgrade matrix, power loss during activation, exhausted root during rebuild |

## Community workflows without project validation

| Workflow | Missing work |
| --- | --- |
| [Split SSH][ssh] | NixOS package/configuration recipe, policy and agent forwarding tests |
| [Split dm-crypt][dmcrypt] | Packaging and disposable storage/unlock tests |
| [Split wallet][wallet] | Application-specific setup and RPC tests |
| [Screen sharing][screen] | Supported NixOS setup, explicit access controls and end-to-end test |
| [Network printers][printer] | NixOS printing configuration and actual print test |
| [Language/localization][locale] | Layout switching, input methods, fonts and application localization tests |
| [MAC randomization][mac] | Physical network-device and reconnect tests |

## Outside template acceptance

- Host installation, disk encryption, Anti Evil Maid, dom0 login/MFA and
  hardware certification are not supplied by this template.
- Qubes policy settings in dom0 remain native Qubes configuration.
- Package availability in nixpkgs is not proof of Qubes integration.
- Installing a missing feature is not evidence that its isolation or recovery
  behavior works. Record actual versions, commands and results before promoting
  a row to tested coverage.

[index]: https://doc.qubes-os.org/en/r4.3/index.html
[minimal]: https://doc.qubes-os.org/en/r4.3/user/templates/minimal-templates.html
[ctap]: https://doc.qubes-os.org/en/latest/user/security-in-qubes/ctap-proxy.html
[updates]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-update.html
[salt]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/salt.html
[guivm]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/gui-domain.html
[audiovm]: https://forum.qubes-os.org/t/audio-qube/20685
[gpg1]: https://doc.qubes-os.org/en/r4.3/user/security-in-qubes/split-gpg.html
[contrib]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/installing-contributed-packages.html
[kernels]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/managing-vm-kernels.html
[resize]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/resize-disk-image.html
[usb]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/usb-qubes.html
[block]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-use-block-storage-devices.html
[network]: https://doc.qubes-os.org/en/r4.3/developer/system/networking.html
[audio]: https://doc.qubes-os.org/en/r4.3/developer/system/audio.html
[gui]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/gui-configuration.html
[disposable]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/disposable-customization.html
[persist]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/bind-dirs.html
[backup]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-back-up-restore-and-migrate.html
[suspend]: https://doc.qubes-os.org/en/r4.3/user/troubleshooting/resume-suspend-troubleshooting.html
[memory]: https://doc.qubes-os.org/en/r4.3/developer/services/qmemman.html
[ssh]: https://forum.qubes-os.org/t/split-ssh/19060
[dmcrypt]: https://github.com/rustybird/qubes-split-dm-crypt
[wallet]: https://forum.qubes-os.org/t/how-to-set-up-a-split-bitcoin-wallet/19017
[screen]: https://forum.qubes-os.org/t/sharing-a-screen-across-qubes/19059
[printer]: https://forum.qubes-os.org/t/configuring-a-network-printer/19056
[locale]: https://forum.qubes-os.org/t/language-localization/19001
[mac]: https://forum.qubes-os.org/t/anonymizing-your-mac-address/19072
