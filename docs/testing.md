# Test results

Development status: no published binary release. Final RPM acceptance is
incomplete. Earlier integration results do not certify an untested release.

## Test targets

| Component | Version |
| --- | --- |
| Qubes OS / Xen | 4.3.1 / 4.19.4, x86_64 |
| Stock Qubes VM kernel | `6.18.31-1.qubes.fc41.x86_64`, matching initramfs/modules |
| Stable nixpkgs | `5e2305d577ca00acbba631b05cb1094d172b29f3` (26.05) |
| Unstable nixpkgs | `e94cb152ed51bd6e24eb4a41f1460252beb52cd2` (development 26.11) |
| Build tool | Nix 2.32.1; image finalization also tested without KVM |

Unstable results apply to the pinned snapshot, not a released NixOS 26.11.

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
| Complete release runtime acceptance | Pending | Pending |

Wrong-key verification rejected the RPM; verification with the matching public
key accepted it. Diagnostic boot assertions are in
[`tests/boot.nix`](../tests/boot.nix). Diagnostic images enable console autologin
and must not be distributed as normal templates.

## Stable integration coverage

These checks passed on the integrated stable configuration. Repeat the required
checks against each final release artifact; unstable coverage is not implied.

| Area | Checks completed |
| --- | --- |
| Guest startup | QubesDB, qrexec, Xen modules, device permissions, root/user RPC and sudo |
| Persistence | AppVM home and `/usr/local` survive restart; root changes reset; template generation propagates after shutdown/restart |
| Storage growth | Native root and private-volume resizing preserves data and expands the filesystem |
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
| Maintenance settings | Native deduplication and 1 GiB/3 GiB cleanup thresholds enabled; no automatic generation-deletion timer |
| Guest power hooks | Suspend/resume preparation RPCs complete; networking works afterward |

The audio permission test used synthetic input. Guest power-hook tests do not
establish physical system suspend/resume coverage. Device tests used read-only
data access or synthetic devices.

## Remaining release checks

- Complete fresh installations and full runtime acceptance for both variants.
- Repeat normal startup serially: one concurrent install/start test exceeded
  the default qrexec startup timeout; a retry succeeded. The cause is not yet
  isolated, and the timeout has not been increased.
- Complete unstable update, rollback and cross-qube desktop/device tests.
- Verify installation through the published GitHub-backed template repository.

## Journal diagnostics

Acceptance requires zero failed system and user units after successful
operations. Upstream diagnostics remain visible:

- Stock PVH ACPI/PCI warnings also occur in a Fedora comparison guest.
- NixOS D-Bus broker reports duplicate service registrations while services
  remain healthy.
- Qubes' graphical-seat setup tries to persist a rule in a read-only NixOS
  directory; GUI, clipboard and input tests pass despite that message.
- An upstream memory-hotplug udev rule reported a failed write during one test;
  all exposed memory blocks were online when checked. This remains unresolved.
- Early external-initramfs handoff emits API-filesystem warnings.

See [adaptations and upstream proposals](adaptations.md) for causes and scope.

## Size and icons

| Measurement | Stable | Unstable |
| --- | --- | --- |
| System closure, NAR data | 5.347 GiB | 5.434 GiB |
| Pre-release compressed signed RPM | 1.415 GiB | 1.436 GiB |

Closure size is not allocated disk usage. Native compression, debug stripping,
documentation selection and one MBROLA voice per language reduce size without
removing the default applications or Qubes roles.

GraphicsMagick 1.3.47 and 1.3.48 reject quoted font names in some XFCE SVG icons.
The same icons pass with 1.3.45. Qubes' unchanged image handler therefore leaves
some menu icons missing; application launch and menu updates still work.
