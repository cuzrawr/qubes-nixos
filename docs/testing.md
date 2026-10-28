# Test coverage

Results apply to the listed revisions, profiles and operations. A passing boot
does not establish feature parity or support for untested devices.
Confidence: high for recorded passes; untested cases are marked UNVERIFIED.

Release changes: [versions.txt](../versions.txt).
Missing features and wider test gaps: [feature gaps](feature-gaps.md).

## Targets and artifacts

| Component | Tested version |
| --- | --- |
| Qubes OS / Xen | 4.3.1 / 4.19.4, x86_64 |
| Stock Qubes VM kernel | `6.18.31-1.qubes.fc41.x86_64`, matching initramfs/modules |
| Stable nixpkgs | `5e2305d577ca00acbba631b05cb1094d172b29f3` (26.05) |
| Unstable nixpkgs | `e94cb152ed51bd6e24eb4a41f1460252beb52cd2` (26.11) |
| Build tool | Nix 2.32.1; image finalization also tested without KVM |
| Reference guests | Fedora 43 and Debian 13 with the same Qubes VM kernel |

| Source/artifact | Coverage |
| --- | --- |
| [v0.1.0](https://github.com/cuzrawr/qubes-nixos/releases/tag/v0.1.0), signed tag and build commit [155d51a](https://github.com/cuzrawr/qubes-nixos/commit/155d51ab251e01c484949adeb064734ecd919711) | Published stable/unstable XFCE RPMs; final artifact checks on 2026-10-07 |
| 0.1.1 candidate source `faa8433` | Four profile evaluations and system builds; source/runtime checks below |
| Source `d9263d0` | Four system builds; audio defaults/optional-role evaluation on both pins; stable minimal audio enable, transport, disable and reboot |
| 0.1.1 minimal candidate RPMs | Both signed and installed with native `qvm-template`; these are not the final release artifacts |
| Candidate build `ce6fb25` | Both XFCE signed-RPM upgrades; both minimal fresh installs; customized source migration and renamed backup restore on both XFCE pins; bounded stable memory-growth check |
| Published build `5695e16` | Stable XFCE: native signed-RPM reinstall, exact system/source, template root/private reset, dependent AppVM private checksums retained across two boots, zero failed system/user units |
| Published repository | All four RPM sizes and SHA256 hashes match GitHub assets and signed metadata; checksum and metadata signatures verified; Qubes Template Manager lists all four templates |
| Native repository client | Refreshed listing contains all four templates; stable minimal downloads through the configured UpdateVM; project signature, header and payload verified |
| Published source | Both XFCE templates retrieve the signed tag through UpdatesProxy without a NetVM; commit and NAR hash match the build |

Final RPM installation for unstable XFCE and both minimal profiles remains
UNVERIFIED. Clipboard, file-transfer and other transport regressions on the final
installed RPMs remain UNVERIFIED. Earlier artifact and system-configuration
coverage is listed separately below.

Source checks cover Nix formatting, flake evaluation, path adaptation, template
name validation, signing isolation/failure cases and ASCII Markdown. The
[CI workflow](../.github/workflows/check.yml) runs these checks; it does not boot
Qubes guests or replace runtime acceptance.

## 0.1.1 source and minimal coverage

| Check | Stable | Unstable |
| --- | --- | --- |
| Full-profile selection comparison | Every selected package retained; native X11 font index added | Same |
| Full-profile settings comparison | XFCE/audio, privilege, boot and Nix defaults retained except documented resize ordering | Same |
| 0.1.0 source upgrade | Custom package and scalar option retained through rebuild and reboot; zero failed system/user units | Same |
| Full-profile audio | Captured playback; synthetic microphone denied, allowed and revoked through native attachment | Same |
| Minimal startup | Root qrexec, denied user sudo/su, locked root password, Xorg, update proxy; zero failed system/user units | Same |
| Minimal AppVM persistence | Repeated boots; home and `/usr/local` retained, root changes discarded; template generation inherited | Same |
| Minimal clipboard and files | Both directions between stable/unstable AppVMs; Xterm configured to use CLIPBOARD | Same |
| Minimal root Xterm | Administrator window and command execution | Same; default launch without font/resource overrides |
| Minimal networking | DNS/HTTPS, native firewall deny and recovery | Same |
| Headless minimal updates | Concurrent starts share one job; added software; check preserves lock file; failed build preserves generation/notification; rollback | Same |
| Minimal optional roles | UNVERIFIED activation/removal combination | Audio units start; USB, Split GPG, UpdateVM and NetworkManager entry points appear; restoring minimal removes them and stops audio; zero failed units |

- Source-upgrade checks use clones of the released XFCE templates. They retain
  a custom package and cleanup setting in the original application selection.
  They do not establish packaged RPM upgrade coverage.
- Headless-update checks keep the recorded nixpkgs revisions to isolate the
  integration. Failure cases deliberately fail the update unit; rollback
  restores the baseline and zero failed units.
- Optional-role checks verify activation and removal, not every device or
  cross-qube workflow in the minimal profile.
- Stable minimal at `d9263d0`: audio enabled and disabled through normal rebuilds
  and reboots; captured playback and synthetic microphone deny/allow/revoke
  passed. Disabled configuration has no PipeWire sockets or audio session hook.
  Both states have zero failed system/user units. The same runtime cycle on
  unstable at this source is UNVERIFIED.
- Clipboard tests launch Xterm with `XTerm*selectToClipboard:true`.
  Default-menu Xterm selection behavior is UNVERIFIED; use the
  [configured command](../README.md#minimal-templates).
- Audio uses synthetic input. After revocation, the first 20 ms contained
  previously buffered samples; a new tone was not delivered on either pin.
- Final-artifact clipboard, file-transfer and other transport regressions are
  UNVERIFIED until tested on the final installed RPMs.

### Device enumeration

An unstable XFCE source-upgrade clone passed native USB attach/detach checks:

| Device class | Verified | UNVERIFIED |
| --- | --- | --- |
| Camera | UVC driver bound; video device nodes present | Frame capture, applications and sustained streaming |
| Bluetooth | btusb driver bound; HCI device present | Pairing and peripheral operation |

Kernel warnings remain, including unsupported HCI LE Coded PHY usage.
Enumeration alone does not establish device functionality.

## Root resize regression

Coverage: cold growth, live growth, preserved file checksums, network recovery
and failed system/user units. The regression uses the default 60-second qrexec
timeout. Timings are observations, not startup guarantees.

| Case | Result |
| --- | --- |
| Released 0.1.0 stable, pending root growth with a NetVM | Reproduces [issue #1](https://github.com/cuzrawr/qubes-nixos/issues/1): qrexec startup timeout |
| Same case with a diagnostic timeout increase | Boot 129.2 seconds; `udevadm settle` fails after 120 seconds; filesystem remains smaller than volume |
| 0.1.1 ordering, networked stable cold growth | Boot 12.29 seconds; resize 0.73 seconds; checksum retained |
| Repeated networked stable growth | Boot 11.12 seconds; resize 0.79 seconds |
| Stable live growth | 1.83 seconds; filesystem expanded; checksum retained |
| Stable network detach/reattach after growth | HTTPS recovered; zero failed units |
| Automated stable/unstable regression | Cold/live growth, checksums and zero failed system/user units passed |
| Unstable networked cold growth | Boot 10.40 seconds; baseline 11.74 seconds |
| Stable minimal without a NetVM | Cold/live growth and checksums passed; growth boot 9.90 seconds, baseline 10.14 seconds |
| Stable minimal AppVM root inheritance | Enlarged template filesystem inherited after template shutdown and AppVM restart |

The controlled comparison changes service ordering only; Qubes resize/network
programs are unchanged. Run [`tests/lab-resize.py`](../tests/lab-resize.py) in
dom0 on a dedicated, stopped test TemplateVM. It grows root by 2 GiB total.
Test with and without a NetVM. Do not run it on a template containing needed data.

Very large volumes, interrupted growth and every Qubes storage backend remain
UNVERIFIED. User procedure: [resizing](resizing.md).

## Published XFCE artifact coverage

This section applies to both v0.1.0 RPMs unless stated otherwise. It is not a
claim that every check has been repeated on the 0.1.1 artifacts.

| Area | Checks passed |
| --- | --- |
| Build | Image finalization without KVM; native template RPM creation; separate signing |
| Signature checks | Matching public key accepts the RPM; wrong key rejects it; signed checksums and published asset digests match |
| Installation | Native RPM install and post-install RPC; all 58 embedded source files match the signed build commit |
| Published repository | Stable through Template Manager; unstable through `qvm-template`; metadata/RPM verification through NixOS UpdateVMs |
| Boot | Stock PVH kernel reaches NixOS stage 2; matching Xen modules; repeated TemplateVM/AppVM starts; zero failed system/user units |
| Guest agents | Both: guest-agent startup; stable also explicitly checks QubesDB, root/user RPC, device permissions and sudo |
| Persistence | AppVM home and `/usr/local` survive restart; root changes reset; template generation propagates after shutdown/restart |
| Replace template | AppVM private data survives template delete/install and reassignment |
| Networking | DNS/HTTPS, networkless-template UpdatesProxy, NixOS as NetVM, native firewall deny/recovery |
| Desktop | Both: Xorg and Firefox launch; stable: XFCE windows, labeled notifications and menu refresh; unstable: native StartApp and Atril |
| Clipboard | Copy/paste in applications and native Qubes shortcuts; stable/Fedora and stable/unstable transfers in both directions |
| Files | Both: native file copy and PDF opening; stable: Thunar copy-to-qube and ordinary text/URL opening |
| Disposables | Root/private isolation, application-specific MIME override, GUI editing round trip |
| Conversion | Both: image/PDF conversion; stable: PNG dimensions/pixels, PDF page size/colors and password-protected PDF output |
| Audio | Captured playback; synthetic microphone allowed only through native attachment; revocation blocks new input |
| Devices | Both: USB mass-storage attachment, read-only block export and synthetic input forwarding; stable: synthetic USB export |
| Backup | Encrypted Qubes backup, restore and boot with private data preserved |
| NixOS update | Native GUI/RPC adds software, survives activation and propagates to AppVMs; failed build preserves generation and notification; rollback despite invalid source |
| Update customization | Unstable: dotted configuration names, input overrides and unchanged lock file during update checks |
| Split GPG 2 | Cross-qube signing/decryption; client cannot export private keys; upstream tests pass except the upstream-skipped pinentry case |
| RPC clients | Stable: synchronous/asynchronous Python calls to `qubes.GetDate` |
| UpdateVM | Both: dom0 update check without installing dom0 packages; stable: signed repository query/download, altered metadata rejection and verified RPM download |
| Optional roles | Stable: disabled UpdateVM/NetworkManager configurations boot; disabled UpdateVM removes its helper and RPCs |
| Store maintenance | Deduplication; GC removes unreferenced objects while preserving roots and all system generations; zero failed units |
| Maintenance defaults | 1 GiB/3 GiB cleanup thresholds; no automatic generation-deletion timer |
| Guest power hooks | Stable: suspend/resume preparation RPCs complete; networking works afterward |

- Guest power hooks do not test physical host suspend/resume.
- Device tests use read-only access or synthetic devices; they do not cover
  every class of USB, PCI, block or input device.
- Small root/private increases preserve data. The networked root-growth
  failure and its regression coverage are listed separately above.
- Audio permission checks use synthetic signals, not physical microphones.

Both release AppVMs pass `nix-store --verify --check-contents` after store
optimisation. Each path audit checks 63 script interpreters and 52 RPC entries,
including executable handlers, native TCP targets and optional policy sockets.

Diagnostic boot assertions are in [`tests/boot.nix`](../tests/boot.nix).
Diagnostic images enable console autologin and are not distributable templates.

## Signed image upgrade and recovery

Qubes 4.3; source/build commit `ce6fb25`:

| Operation | Verified coverage |
| --- | --- |
| Stable/unstable XFCE signed-RPM upgrade | Native replacement of the released image; expected system and source; template root/private reset; dependent AppVM private checksums retained across two boots; zero failed system/user units |
| Stable/unstable minimal signed-RPM install | Native fresh import; exact system/source; two TemplateVM and AppVM boots; root qrexec, Xorg, locked root password, denied user sudo/su and no audio; zero failed system/user units; AppVM root resets while home and `/usr/local` persist; template proxy HTTPS and AppVM DNS/direct HTTPS |
| Customized stable/unstable source migration | Complete frozen source tree; custom package, scalar option, configuration and data markers retained; unchanged stateVersion; retained generations, reboot and update-proxy HTTPS; zero failed system/user units |
| Stable/unstable backup restore | Separate conflict-renamed TemplateVMs; exact backed-up root/private volumes and system restored; original templates unchanged |

These checks do not establish arbitrary custom-module compatibility or restore
AppVM application data. Visible application interaction and complete transport
regressions are separate checks.

## Application interaction

All four signed images from `ce6fb25`, using dependent AppVMs:

| Check | Verified coverage |
| --- | --- |
| Stopped AppVM | `qvm-run --no-autostart` fails and leaves it stopped; ordinary GUI and headless `qvm-run` start it |
| Concurrent windows | Three visible Xterms while six commands run in seeded order |
| Command handling | User identity, literal quoting, exit status 37, missing-command status 127, running generation and private marker reads |
| Privileges | User sudo allowed in XFCE, denied in minimal; administrator qrexec works in both |
| Restart | Private marker retained; expected system and VM properties unchanged; zero failed system/user units |
| XFCE Firefox | Visible local-file page with the expected title; normal window close on both pins |

These are bounded deterministic checks (seed 411), not exhaustive fuzzing.
They do not cover every application dialog or command/shutdown race. Visible
windows and zero failed units do not establish warning-free application logs.

## Timezone and Xterm fonts

Both pins, XFCE and minimal; all four TemplateVMs and their AppVMs:

- Cold `qvm-run` opens a visible default Xterm without a font-load warning.
- Xlib loads the exact default Unicode font and the `fixed` fallback.
- `timedatectl` matches Qubes' timezone; `/etc/localtime` uses `/etc/zoneinfo`.
- Expected system generation; zero failed system/user units.
- VM identity, settings and halted state retained after each check.

These checks use the built system configurations. Final RPM installation is
listed separately above.

## Update and recovery commands

Stable XFCE on Qubes 4.3:

- Root and user qrexec status commands; zero failed system/user units.
- Configuration archive creation, extraction and full source comparison.
- Numbered lock-file backups and restoration into a staged source tree.
- Build of the recovered source produces the running system's exact store path.
- Published-source retrieval through the template's native update proxy.

These checks do not activate a new package set or replace a template volume.
Generation rollback and failed-update coverage are recorded above. Native image
replacement and restored-system checks are listed separately. Arbitrary
customized-source merges and failed-boot recovery remain UNVERIFIED.

## Startup under load

Coverage: three paired v0.1.0 AppVM starts with Qubes defaults of 400 MiB initial
RAM, 4000 MiB maximum, 2 vCPUs and a 60-second qrexec timeout.

| Check | Stable | Unstable |
| --- | --- | --- |
| `qvm-start`, three runs | 17.23, 15.38, 16.11 seconds | 19.65, 19.14, 19.26 seconds |
| Failed system/user units | 0 / 0 | 0 / 0 |
| Private persistence and root reset | Pass | Pass |
| Kernel OOM/allocation failures | None observed | None observed |

Concurrent template import and AppVM startup are not covered by this pass.
One combined import/start test exceeds the default startup timeout; its cause
is unresolved. Serial installs and repeated boots pass with the default timeout.

## Journal and kernel diagnostics

Acceptance requires zero failed system and user units after successful
operations. Checks include dmesg, system/user journals, Xorg and dom0
qrexec/GUI/console logs. Messages remain visible; exit codes are not suppressed.

Fresh Fedora 43 and Debian 13 reference AppVMs reach a running state with zero
failed system/user units. Confidence: high for the comparisons below; a matching
message alone does not establish that all consequences are harmless.

| Diagnostic | Coverage / finding |
| --- | --- |
| PVH ACPI/PCI, nomodeset and IMA | Present in NixOS, Fedora and Debian |
| Unsupported discard on private storage | Present in all three; depends on the virtual block device |
| Xorg dummy-driver probe, VGA arbiter, missing render node | Present in all three |
| Xorg font lookup | Both 0.1.1 pins boot with valid indexed font paths; stable fixed-font Xterm and unstable default root Xterm pass |
| NixOS duplicate D-Bus registrations and graphical-seat setup | Messages remain; related GUI, clipboard and input checks pass |
| Xen `xl.conf` | Unstable minimal reboot: packaged configuration present, daemon active, no missing-file error |
| Xen CPU-count query errors | Also present in Fedora/Debian; device daemon remains active on all three |
| Obsolete `StandardOutput=syslog` | Also present in Fedora/Debian; systemd maps it to journal output |
| Unstable I/O-pressure threshold | systemd 261.2 rejects an inherited-setting override with `EBUSY`; actual user manager and API reproducer retain registered watches |
| Memory-hotplug write | Kernel trace: Xen auto-online succeeds, then udev receives already-online; 768 MiB allocation succeeds, all blocks online, zero failed units. Stock Fedora also reproduces the warning |
| vmemmap order-9 allocation warning | Reproduced on the stable signed image; usable memory subsequently grows, all sampled blocks are online, allocation checks pass and no OOM occurs |
| Xorg missing acpid socket | Present on NixOS; physical suspend/resume remains UNVERIFIED |
| External-initramfs handoff | Early API-filesystem warnings remain visible |

The pressure-watch check verifies registration, not event latency or storage
performance. The hotplug result covers the traced duplicate-online case; an
offline block, OOM or failed allocation requires separate investigation.

The stable signed-image memory check reproduces one order-9 warning, then
observes MemTotal grow from 718940 to 2322484 KiB. A 768 MiB mapping passes
page-write and sampled-read checks; all sampled memory blocks are online, with
no OOM or failed system/user units. About 53 MiB of process swap is observed;
the full mapping is not continuously resident. Settings stay unchanged.
A supported base-page fallback is a high-confidence inference from
[matching kernel source](https://github.com/gregkh/linux/blob/v6.18.31/mm/sparse-vmemmap.c#L416-L465)
and observed recovery; its branch was not traced. This is one bounded boot,
not a claim that every allocation warning is harmless.
[Causes and upstream proposals](adaptations.md).

## Shutdown

Both XFCE variants complete native shutdown and final filesystem teardown.
The console is not error-free:

- Initial `/lib/modules` unmount reports `target is busy` while udev maps module
  indexes; late teardown releases them and unmounts successfully. Fedora and
  Debian show the same diagnostic at `/usr/lib/modules`.
- `qubes-gui-agent` sometimes exits with status 1 during shutdown, also in Fedora.
- Shutdown during unfinished startup jobs can interrupt them and initially
  leave `/home` busy; final teardown unmounts it.

Zero failed units describes the running system after successful operations,
not every intermediate shutdown message.

## Size and icons

Measurements for the published v0.1.0 XFCE artifacts:

| Measurement | Stable | Unstable |
| --- | --- | --- |
| System closure, NAR data | 5.347 GiB | 5.434 GiB |
| Compressed signed RPM | 1.410 GiB | 1.438 GiB |
| `nix-store --optimise` reported saving in an AppVM | 73.0 MiB | 60.7 MiB |

- Closure size, allocated disk use and compressed RPM size are different measures.
- Store optimisation retains packages and generations. AppVM savings disappear
  when root resets; run maintenance in the template for persistent savings.
- RPM build macros retain about 301 MiB of compiler dependencies per closure.
  The stock package remains. Mesa/LLVM supplies rendering; speech packages
  supply accessibility.
- The image copy step does not preserve hard links; see the
  [image-builder proposal](adaptations.md#nixos-image-builder-preserve-hard-links).

GraphicsMagick 1.3.47/1.3.48 reject quoted font names in some XFCE SVG icons;
the same icons pass with 1.3.45. The unchanged Qubes image handler leaves some
menu icons missing. Application launch and menu updates pass.
