# Increase disk space

Applies to stable and unstable, XFCE and minimal. Stock Qubes kernel/initramfs.

## Choose the right disk

| Need more room for | Change in Qubes Settings |
| --- | --- |
| Installed software, `/nix`, NixOS generations | TemplateVM: system storage / root |
| An AppVM's downloads, documents, `/home` | That AppVM: private storage |
| Both in a StandaloneVM | Its root or private storage, as appropriate |

Check Qubes' disk-space widget first. A larger virtual disk does not add space
to the physical storage pool. These instructions only grow disks.

## GUI procedure

1. Back up important data. Shut down dependent AppVMs.
2. Open the relevant qube's **Settings**, **Basic**, **Disk storage**.
3. Increase **System storage** for template software, or **Private storage**
   for that AppVM's files. Apply the change.
4. Start the qube. For template root growth, start the TemplateVM first.
5. In a dom0 terminal, replace `QUBE` with its name:

```sh
qvm-run -p -u root QUBE 'df -h / /rw'
```

6. Check the increased size: `/` for root, `/rw` for private storage.
   Filesystem capacity is slightly below the configured disk size.
7. Shut down the TemplateVM, then start its AppVMs.

## Command line

Run in dom0. Sizes are the new total, not the amount to add.

```sh
# Software space: grow the template root to 24 GiB.
qvm-volume extend TEMPLATE:root 24GiB
qvm-start TEMPLATE
qvm-run -p -u root TEMPLATE 'df -h /'
qvm-shutdown --wait TEMPLATE

# User files: grow an AppVM's private disk to 8 GiB.
qvm-volume extend APP:private 8GiB
qvm-start APP
qvm-run -p -u root APP 'df -h /rw'
```

- Skip `qvm-start` if the qube is already running.
- Native live root growth also works: start the template, extend its root,
  check `df`, then shut it down before restarting its AppVMs.
- Do not run `mkfs`, repartition the guest manually, or shrink a volume.

## Startup timeout on 0.1.0

Confirmed case: a pending root resize plus a NetVM can deadlock early boot.
Increasing `qrexec_timeout` alone can leave the filesystem unchanged.
Confidence: high; reproduced with the released stable image.

1. Leave dependent AppVMs stopped.
2. In the TemplateVM's Settings, note its current networking choice. Select
   **none** temporarily if it has a NetVM.
3. Start the TemplateVM. Check `df -h /` with the command above.
4. Shut it down; restore the networking choice if changed.
5. Start one dependent AppVM and check it before starting the rest.

The 0.1.1 source changes the resize service ordering; release acceptance is
tracked in [testing](testing.md). For another startup failure, collect the
console and journal instead of repeatedly increasing timeouts:

```sh
# In a bootable guest, as root:
systemctl --failed
journalctl -b -u qubes-rootfs-resize -u qubes-nixos-rootfs-resize --no-pager
```

References: [Qubes disk resizing](https://doc.qubes-os.org/en/r4.3/user/advanced-topics/resize-disk-image.html),
[ordering change](../WHY.md#root-resize-ordering),
[non-default systemd settings](configuration.md#boot-and-service-ordering).
