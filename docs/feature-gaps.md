# Missing and untested features

Target: Qubes 4.3 with its external PVH kernel.

- [Test coverage](testing.md) lists the versions, profiles and checks that passed.
- A pass in one profile does not establish support in every profile.
- **Untested does not mean broken or working.**

Confidence: high for the package/module inventory and recorded tests.

## Not included

These need packaging or integration before they can be supported.

| Feature | Missing part |
| --- | --- |
| [CTAP proxy / browser FIDO2][ctap] | `qubes-ctap` package and service setup. USB storage tests do not cover security tokens |
| [Central Qubes updater][updates] | NixOS backend. Use the NixOS update service or `nixos-rebuild` |
| [Salt guest management][salt] | Qubes Salt connector and NixOS integration; no NixOS management-disposable setup |
| [Dom0 firmware updates][firmware] | `fwupd-qubes-vm` in a NixOS UpdateVM. RPM/template downloads use different helpers |
| [NixOS GUI domain][guivm] | GUI daemon, administration tools and `sys-gui` configuration. The guest Xorg agent does not provide this role |
| [NixOS AudioVM][audiovm] | Audio provider daemon and configuration. Guest audio transport is included |
| [Split GPG 1][gpg1] | Legacy package. Split GPG 2 is included instead |
| [Snap, Thunderbird and idle shutdown helpers][minimal] | `qubes-snapd-helper`, Qubes Thunderbird integration and `qubes-app-shutdown-idle` |
| [Guest kernel/initrd][kernels] | No NixOS kernel/initrd or HVM boot profile; shipped profiles use the Qubes external PVH kernel |

**Contributed packages:** need Nix packaging and tests too.
Their [RPM/APT instructions][contrib] cannot install them into NixOS.

## Not yet tested

These cases have no recorded test, even where narrower tests passed.
**An installed package or service is not proof that the workflow works.**

| Area | Untested cases |
| --- | --- |
| [Storage growth][resize] | Very large volumes, interrupted growth, every Qubes storage backend |
| [USB and input][usb] | Physical keyboard/mouse through a NixOS USB qube; security tokens, smartcards, cameras, scanners, Bluetooth and other device classes |
| [Block devices][block] | Writable removable media, removal during writes, optical media |
| [Networking][network] | IPv6, custom addressing/DNS, VPN kill switches, physical Wi-Fi and MAC randomization |
| [Audio][audio] | Physical speakers/microphones, USB/Bluetooth headsets, non-dom0 AudioVM, reconnects and sustained load |
| [GUI][gui] | Multiple monitors, HiDPI, fullscreen variations, monitor changes, non-dom0 GuiVM, accessibility and non-US input methods |
| [Files and disposables][disposable] | Large or malformed-file stress tests, interrupted transfers, alternative disposable configurations |
| [Persistence][persist] | Full `custom-persist` coverage, unusual bind targets and conflicts with NixOS-generated `/etc` symlinks |
| [Backup and restore][backup] | Cross-host migration, recovery after host-storage failure, very large backups |
| [Suspend/resume][suspend] | Physical host suspend/resume with NixOS clients and device providers; guest preparation RPCs alone do not test this |
| [Memory management][memory] | Sustained pressure, swap exhaustion and the full range of balloon/hotplug transitions |
| NixOS rebuilds | Power loss during activation, root volume exhausted during a rebuild |
| [StandaloneVMs][standalones] | Creation from these templates, independent updates and persistent system changes |

[Install, upgrade and regression coverage](testing.md) |
[Known diagnostics](adaptations.md).

Camera and Bluetooth driver enumeration passed on an unstable XFCE clone.
Capture, pairing and actual peripheral use remain untested.

## Other setups

No tested NixOS instructions are supplied for these workflows:

- [Split SSH][ssh]: agent forwarding and RPC policy.
- [Split dm-crypt][dmcrypt]: package setup, storage and unlock workflow.
- [Split wallet][wallet]: application setup and RPC access.
- [Screen sharing][screen]: capture tools and access controls.
- [Network printers][printer]: printing configuration and physical output.
- [Localization][locale]: layouts, input methods, fonts and translated applications.
- [MAC randomization][mac]: physical network devices and reconnect behavior.

Scope:

- [Qubes documentation][index], linked guides and selected forum workflows.
  Not every forum thread.
- Host installation, disk encryption, Anti Evil Maid, dom0 login/MFA and
  hardware certification are outside this template.
- Dom0 policy and device permissions remain Qubes configuration.

[index]: https://doc.qubes-os.org/en/r4.3/index.html
[minimal]: https://doc.qubes-os.org/en/r4.3/user/templates/minimal-templates.html
[ctap]: https://doc.qubes-os.org/en/r4.3/user/security-in-qubes/ctap-proxy.html
[updates]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-update.html
[firmware]: https://doc.qubes-os.org/en/r4.3/user/how-to-guides/how-to-update.html#firmware-update-methods
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
[standalones]: https://doc.qubes-os.org/en/r4.3/user/advanced-topics/standalones-and-hvms.html
[ssh]: https://forum.qubes-os.org/t/split-ssh/19060
[dmcrypt]: https://github.com/rustybird/qubes-split-dm-crypt
[wallet]: https://forum.qubes-os.org/t/how-to-set-up-a-split-bitcoin-wallet/19017
[screen]: https://forum.qubes-os.org/t/sharing-a-screen-across-qubes/19059
[printer]: https://forum.qubes-os.org/t/configuring-a-network-printer/19056
[locale]: https://forum.qubes-os.org/t/language-localization/19001
[mac]: https://forum.qubes-os.org/t/anonymizing-your-mac-address/19072
