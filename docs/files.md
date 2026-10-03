# Repository files

RPMs, private keys, build caches and test logs stay outside the repository.
`repository/` contains only public installation files and signed metadata.

```text
.github/workflows/check.yml
.github/workflows/pages.yml
.gitignore
README.md
WHY.md
configuration.nix
docs/adaptations.md
docs/comparison.md
docs/configuration.md
docs/distribution.md
docs/files.md
docs/github.md
docs/recovery.md
docs/testing.md
flake.lock
flake.nix
lib/image.nix
lib/template-rpm.nix
modules/boot.nix
modules/core.nix
modules/default.nix
modules/desktop.nix
modules/devices.nix
modules/networking.nix
modules/persistence.nix
modules/split-gpg.nix
modules/update-vm.nix
modules/updates.nix
modules/users.nix
pkgs/core-agent.nix
pkgs/default.nix
pkgs/guest-paths.nix
pkgs/gui-agent.nix
pkgs/gui-common.nix
pkgs/img-converter.nix
pkgs/input-proxy.nix
pkgs/libvchan.nix
pkgs/linux-utils.nix
pkgs/notification-proxy.Cargo.lock
pkgs/notification-proxy.nix
pkgs/overlay.nix
pkgs/pdf-converter.nix
pkgs/qrexec.nix
pkgs/qubesdb.nix
pkgs/relocate-paths.py
pkgs/sources.nix
pkgs/split-gpg2.nix
pkgs/update-vm.nix
pkgs/usb-proxy.nix
repository/RPM-GPG-KEY-qubes-nixos
repository/index.html
repository/qubes-nixos.repo
repository/rpm/r4.3/x86_64/repodata/*-other.xml.zst
repository/rpm/r4.3/x86_64/repodata/*-primary.xml.zst
repository/rpm/r4.3/x86_64/repodata/*-filelists.xml.zst
repository/rpm/r4.3/x86_64/repodata/repomd.xml
repository/rpm/r4.3/x86_64/repodata/repomd.xml.asc
scripts/sign-template.sh
tests/boot.nix
tests/core.nix
tests/desktop.nix
tests/lab-network.py
tests/test_paths.py
```

Metadata filenames begin with their content checksum and change per release.
