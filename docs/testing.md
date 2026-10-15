# Test results

## 0.1.1 work in progress

No 0.1.1 release acceptance yet. Confidence: high in the individual results
below; they do not establish coverage of unbuilt or untested artifacts.

| Check | Result |
| --- | --- |
| Four profile evaluations | Pass: stable/unstable XFCE and minimal |
| Minimal candidate RPMs | Both built, signed and installed with native `qvm-template`; final artifacts pending |
| Fresh minimal startup | Both pins: root qrexec, denied user sudo/su, locked root password, Xorg, proxy access, zero failed system/user units |
| Stable minimal AppVM | Two boots, DNS/HTTPS, private persistence, root reset and privilege defaults passed |
| Headless updates, both minimal pins | Concurrent starts shared one job; added software; update check preserved source lock; failed build retained generation/notification; rollback passed |
| Full-profile refactor comparison | Both pins retain every selected package and the XFCE/audio, privilege, boot and Nix settings; only the native X11 font index is added |
| Reproduce issue #1 on v0.1.0 stable | Pass: networked root growth hit the default 60-second qrexec timeout |
| Diagnostic timeout increase | Boot took 129.2 seconds; resize failed at `udevadm settle` after 120 seconds; filesystem stayed smaller than volume |
| Changed service order, networked stable boot | Pass: 12.29 seconds; resize 0.73 seconds; unchanged file checksum |
| Repeat networked growth | Pass: startup 11.12 seconds; resize 0.79 seconds |
| Live stable root growth | Pass: 1.83 seconds; filesystem expanded; unchanged checksum |
| Network detach/reattach after growth | Pass: direct HTTPS recovered; no failed units |
| Automated resize regression | Pass on stable and unstable: cold growth, live growth, data integrity, zero failed system/user units; default qrexec timeout |
| Unstable networked resize startup | 10.40 seconds with pending growth; baseline 11.74 seconds |
| Stable minimal, no NetVM | Cold/live growth and checksums passed; growth boot 9.90 seconds, baseline 10.14 seconds |
| Minimal clipboard and files | Both directions passed between stable/unstable AppVMs; root Xterm administration passed on both |
| Minimal networking | Both passed DNS/HTTPS, native firewall deny and recovery |
| Enlarged template root inheritance | Stable minimal AppVM received the enlarged filesystem after template shutdown/restart |

The reproduction used an isolated clone. Only the service ordering changed
for the successful comparison; upstream resize/network programs were unchanged.
`tests/lab-resize.py` runs in dom0 on a dedicated, stopped test TemplateVM and
grows its root by 2 GiB. Test with and without a NetVM.

Pending: four final RPMs and fresh installs;
optional-role checks; 0.1.0 upgrade with retained AppVM data and reviewed custom
configuration. [Feature gaps](feature-gaps.md) lists wider untested cases.

## Boot log comparison during 0.1.1 testing

Checked dmesg, system/user journals, Xorg and dom0 qrexec/GUI/console logs.
Fresh Fedora 43 and Debian 13 reference AppVMs used the same Qubes kernel.
All reached a running state with zero failed system/user units.
Confidence: high for these comparisons; a matching message is not proof that
all consequences are harmless.

| Diagnostic | Observed / action |
| --- | --- |
| PVH ACPI/PCI, nomodeset and IMA messages | Present in NixOS, Fedora and Debian |
| Unsupported discard on private storage | Present in all three; depends on the virtual block device |
| Xorg dummy-driver probe, VGA arbiter and missing render node | Present in all three |
| NixOS missing font directories | Native indexed font directory and explicit Xorg lookup fixed the gap; both pins boot with valid font paths; stable fixed-font Xterm passed |
| NixOS duplicate D-Bus registrations and graphical-seat setup | Still present; causes and upstream proposals in [adaptations](adaptations.md) |
| Missing Xen `xl.conf` | Found by reviewing the full journal; registration of the packaged default is under test |
| Unstable I/O-pressure threshold warning | Reproduced with systemd 261.2; inherited settings reject the setter with `EBUSY`. Actual user manager and API reproducer retain registered watches; [details](adaptations.md#systemd-inherited-io-pressure-threshold) |
| Memory-hotplug write warning | Kernel tracing confirms successful Xen auto-online followed by udev's already-online result; 768 MiB allocation passed, all blocks online, zero failed units. Also reproduced in stock Fedora; [details](adaptations.md#qubeslinux-duplicate-memory-onlining) |
| Xen CPU-count query errors | Reproduced in fresh Fedora and Debian; native device daemon remains active on all three |
| Obsolete `StandardOutput=syslog` | Also present in stock Fedora and Debian services; systemd maps it to journal output |
| Xorg missing acpid socket on NixOS | Remains visible; GUI and power-hook coverage are separate from physical suspend/resume |
| Other stock-template diagnostics | Fedora logged a balloon allocation warning; Debian logged ALSA-rule and transient audio messages. These do not excuse unrelated NixOS failures |

Headless-update tests pinned inputs to the recorded revisions to exercise
integration changes without an unrelated package upgrade. Failure tests
intentionally produced a failed update unit; successful rollback restored the
baseline and zero failed units.

## 0.1.0 release record

Release [v0.1.0](https://github.com/cuzrawr/qubes-nixos/releases/tag/v0.1.0).
Final artifact checks: 2026-10-07.
Build source: [155d51a](https://github.com/cuzrawr/qubes-nixos/commit/155d51ab251e01c484949adeb064734ecd919711), signed tag `v0.1.0`.

## Test targets

| Component | Version |
| --- | --- |
| Qubes OS / Xen | 4.3.1 / 4.19.4, x86_64 |
| Stock Qubes VM kernel | `6.18.31-1.qubes.fc41.x86_64`, matching initramfs/modules |
| Stable nixpkgs | `5e2305d577ca00acbba631b05cb1094d172b29f3` (26.05) |
| Unstable nixpkgs | `e94cb152ed51bd6e24eb4a41f1460252beb52cd2` (26.11) |
| Build tool | Nix 2.32.1; image finalization also tested without KVM |

## Build and boot checks

| Check | Stable | Unstable |
| --- | --- | --- |
| Image build without KVM | Pass | Pass |
| Native template RPM creation and external signing | Pass | Pass |
| Signature-checked diagnostic RPM installation | Pass | Pass |
| Stock PVH kernel reaches NixOS stage 2 | Pass | Pass |
| Current/booted system links and matching Xen modules | Pass | Pass |
| Second diagnostic boot after orderly shutdown | Pass | Pass |
| Normal desktop RPM install, including post-install RPC | Pass | Pass |
| Exact embedded source matches the signed build commit | Pass | Pass |
| Normal TemplateVM/AppVM startup; zero failed system/user units | Pass | Pass |
| AppVM second boot, private persistence and discarded root changes | Pass | Pass |
| Networkless template UpdatesProxy and AppVM HTTPS | Pass | Pass |
| Published repository installation | Pass: Template Manager GUI | Pass: `qvm-template` CLI |
| AppVM private data preserved through template delete/install | Pass | Pass |

Wrong-key verification rejected the RPM; verification with the matching public
key accepted it. Diagnostic boot assertions are in
[`tests/boot.nix`](../tests/boot.nix). Diagnostic images enable console autologin
and must not be distributed as normal templates.

## Stable integration coverage

Coverage of the stable system closure included in v0.1.0:

| Area | Checks completed |
| --- | --- |
| Guest startup | QubesDB, qrexec, Xen modules, device permissions, root/user RPC and sudo |
| Persistence | AppVM home and `/usr/local` survive restart; root changes reset; template generation propagates after shutdown/restart |
| Storage growth | Small root/private increases preserved data; later networked root growth exposed issue #1, documented above |
| Networking | DNS/HTTPS, networkless-template UpdatesProxy, NixOS as NetVM, firewall deny/recovery |
| Desktop | Xorg/XFCE windows, Firefox, labeled notifications, application menus refreshed after package changes |
| Clipboard | Application copy/paste; native Qubes shortcuts between NixOS and Fedora in both directions, verified from saved text |
| Files | Native file copy, Thunar copy-to-qube action, ordinary text/PDF/URL opening |
| Disposables | Private/root isolation, application-specific MIME override, GUI editing round trip |
| Converters | PNG dimensions/pixels; PDF page size/colors; password-protected PDF output |
| Audio | Captured playback tone; synthetic microphone input only while native attachment permits it |
| Devices | USB mass-storage attachment; read-only block export; synthetic USB export and input forwarding |
| Backup | Encrypted native Qubes backup, restore and boot with preserved private data |
| NixOS updates | Native update RPC adds software, survives activation and reaches dependent AppVMs |
| Failure and rollback | Invalid configuration preserves active generation and pending-update notification; rollback works despite invalid source |
| Split GPG 2 | Cross-qube signing/decryption; client cannot export private keys; upstream unit tests pass except upstream-skipped pinentry case |
| RPC clients | Synchronous and asynchronous Python calls to native `qubes.GetDate` |
| UpdateVM | Signed repository query/download, rejection of altered metadata, verified RPM download and dom0 update check |
| Optional roles | UpdateVM and NetworkManager disabled configurations boot without failed units; disabled UpdateVM removes its helper link and RPCs |
| Store maintenance | Identical files share storage; GC removes unreferenced objects while preserving rooted objects and every system generation; zero failed units afterward |
| Maintenance settings | Native 1 GiB/3 GiB cleanup thresholds enabled; no automatic generation-deletion timer |
| Guest power hooks | Suspend/resume preparation RPCs complete; networking works afterward |

The audio permission test used synthetic input. Guest power-hook tests do not
establish physical system suspend/resume coverage. Device tests used read-only
data access or synthetic devices.

## Unstable integration coverage

The pinned 26.11 configuration also passed:

- Native template installation and exact embedded-source verification.
- Repeated TemplateVM/AppVM startup, zero failed system/user units, HTTPS and
  networkless-template UpdatesProxy.
- AppVM persistence, root reset and template-generation propagation.
- Small root/private-volume growth, preserved data and filesystem expansion;
  this did not cover the later networked resize regression.
- Automatic store deduplication and garbage collection with all system
  generations preserved; zero failed system/user units afterward.
- Native update GUI/RPC, dotted configuration names, ordinary input overrides,
  unchanged lock file during update checks, failed-update notification and rollback.
- Clipboard and file copying in both directions between stable and unstable.
- Read-only block export, USB mass-storage attachment and synthetic input forwarding.
- Audio playback, synthetic microphone attachment and revocation. After revocation,
  the first 20 ms contained previously buffered audio; a new tone was not delivered.
- Network-provider routing and native firewall deny/recovery.
- Encrypted Qubes backup/restore with preserved private data.
- Disposable isolation, image/PDF conversion and disposable GUI editing.
- Split GPG 2 signing/decryption with no client export of private keys.
- Firefox through native StartApp, PDF opening in Atril and an Xorg session.
- Native dom0 update check through the NixOS UpdateVM; no dom0 packages installed.

Tests used the default system closures included in the release. Custom update
options were also activated and exercised in the guest. Final RPM installations
verified all 58 embedded source files against the signed build commit.

## Published repository checks

- Stable installed through Qubes Template Manager; unstable through `qvm-template`.
- Downloads through NixOS UpdateVMs with metadata and RPM signature checks enabled.
- Signed checksums verified with the public key; both RPM digests match the
  published GitHub assets.
- Both templates and AppVMs booted repeatedly with the expected generations,
  working guest agents, Xorg and zero failed system/user units.
- Existing AppVM home and `/usr/local` files survived the delete/install cycle.

## Store integrity and entry points

Both release AppVMs passed `nix-store --verify --check-contents` after store
optimisation. On each variant, the path audit checked 63 script interpreters
and 52 RPC entries. Executable handlers, native TCP targets and optional policy
sockets matched their expected forms. No guest changes were needed.

## Startup under load

Three paired AppVM starts passed with unmodified Qubes defaults: 400 MiB initial
RAM, 4000 MiB maximum, 2 vCPUs and a 60-second qrexec timeout.

| Check | Stable | Unstable |
| --- | --- | --- |
| `qvm-start` completion, three runs | 17.23, 15.38, 16.11 seconds | 19.65, 19.14, 19.26 seconds |
| Failed system/user units after startup | 0 / 0 | 0 / 0 |
| Private persistence and root reset after restart | Pass | Pass |
| Kernel OOM/allocation-failure messages | None observed | None observed |

These checks cover simultaneous AppVM starts, not a concurrent template import.
One concurrent install/start test exceeded the default qrexec startup timeout.
Final serial installations and repeated boots passed with the default timeout.
The concurrent timeout's cause remains unresolved.

## Journal diagnostics

Acceptance requires zero failed system and user units after successful
operations. Upstream diagnostics remain visible:

- Stock PVH ACPI/PCI warnings also occur in a Fedora comparison guest.
- NixOS D-Bus broker reports duplicate service registrations while services
  remain healthy.
- Qubes' graphical-seat setup tries to persist a rule in a read-only NixOS
  directory; GUI, clipboard and input tests pass despite that message.
- An upstream memory-hotplug udev rule reported a failed write; all exposed
  blocks were online. The later 0.1.1 investigation traced this warning to
  duplicate onlining; see the comparison above.
- Early external-initramfs handoff emits API-filesystem warnings.

See [adaptations and upstream proposals](adaptations.md) for causes and scope.

## Shutdown

Both NixOS variants completed native shutdown and final filesystem teardown.
The console is not error-free:

- The first attempt to unmount `/lib/modules` reports `target is busy`.
  `systemd-udevd` still maps module indexes. Late shutdown releases these and
  unmounts the module filesystem successfully.
- The same module-mount diagnostic was reproduced in stock Fedora 43 and
  Debian 13 Qubes guests, at `/usr/lib/modules`.
- `qubes-gui-agent` sometimes exits with status 1 during shutdown. This was
  also reproduced in stock Fedora.
- Shutting down while startup jobs are still running can interrupt those jobs
  and initially leave `/home` busy. Final teardown still unmounted it.

Zero failed system/user units was verified while running, including after
updates and maintenance. It does not describe every intermediate shutdown
message. No failure codes are suppressed or reclassified as success.

## Size and icons

| Measurement | Stable | Unstable |
| --- | --- | --- |
| System closure, NAR data | 5.347 GiB | 5.434 GiB |
| Compressed signed RPM | 1.410 GiB | 1.438 GiB |
| `nix-store --optimise` saving reported in a release AppVM | 73.0 MiB | 60.7 MiB |

Closure size is not allocated disk usage. Native compression, debug stripping,
documentation selection and one MBROLA voice per language reduce size without
removing the default applications or Qubes roles.

Full store optimisation retained the same system generations and packages.
This measures deduplication of existing files, not a smaller replacement RPM.
For a lasting saving, run it in the TemplateVM and restart dependent AppVMs
after shutting the template down. The image builder's copy step is covered in
[upstream proposals](adaptations.md#nixos-image-builder-preserve-hard-links).

The size audit traced RPM's compiler dependency to its build macros. GCC and
its exclusive dependencies account for about 301 MiB in each closure. The
stock package is retained. Mesa/LLVM supplies software rendering, and the
speech packages provide accessibility; these are not unused build leftovers.

GraphicsMagick 1.3.47 and 1.3.48 reject quoted font names in some XFCE SVG icons.
The same icons pass with 1.3.45. Qubes' unchanged image handler therefore leaves
some menu icons missing; application launch and menu updates still work.
