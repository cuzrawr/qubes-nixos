# Distribute templates

The project public key is [published here](../repository/RPM-GPG-KEY-qubes-nixos).
Fingerprint: `4B90 5004 6403 DDD1 B6F1 FCF7 A752 8E30 ED60 389C`.
Published builds: [GitHub Releases](https://github.com/cuzrawr/qubes-nixos/releases).

Build with a committed lock file, complete the acceptance tests, and sign the
RPMs outside Nix. Publish the source commit, nixpkgs pins, checksums, public key
fingerprint and test results with each release. Increase the RPM `release`
argument in `flake.nix` for a replacement build; do not replace an existing
release asset with different bytes.

The upstream template RPM spec supplies a GPLv3+ package label. The contained
components retain their own licenses; this repository's integration source has
no license grant.

Keep private keys outside the repository, build inputs and template. Use a
dedicated `GNUPGHOME` for all signing commands below.

## Sign a local build

From the source checkout:

```sh
nix develop .#release
export GNUPGHOME=/path/to/project-signing-keyring
install -d -m700 "$GNUPGHOME"

# For a new working identity; use its printed fingerprint below.
gpg --quick-generate-key 'YOUR_RELEASE_IDENTITY' rsa3072 sign 0
mkdir -p artifacts
nix run .#sign-template -- YOUR_KEY_FINGERPRINT \
  result-stable/qubes-template-nixos-26.05-xfce-4.3.0-1.noarch.rpm \
  artifacts/qubes-template-nixos-26.05-xfce-4.3.0-1.noarch.rpm
gpg --armor --export YOUR_KEY_FINGERPRINT > artifacts/template-key.asc
```

For unstable, use `result-unstable/` and
`qubes-template-nixos-unstable-xfce-4.3.0-1.noarch.rpm`.
Existing working key: omit key generation. Keep this keyring outside the checkout;
back it up separately. `sign-template` requires an explicit signing keyring.

Back up signing keys and revocation certificates offline. Never upload them
to GitHub. A compromised key requires revocation and a new client trust setup.

## GitHub Releases

GitHub can host the signed RPMs as release assets. Users download them in a
transfer qube and follow the local install instructions in the README.

After signing into `artifacts/`, enter the publishing shell:

```sh
nix develop .#release
(cd artifacts && sha256sum *.rpm > SHA256SUMS)
gpg --local-user YOUR_KEY_FINGERPRINT --armor --detach-sign artifacts/SHA256SUMS
gh release create v0.1.0 --draft --verify-tag \
  --title 'NixOS templates v0.1.0' --notes-file release-notes.txt \
  artifacts/*.rpm artifacts/template-key.asc artifacts/SHA256SUMS artifacts/SHA256SUMS.asc
```

Create and push the reviewed source tag first. Review the draft and publish it
in GitHub. Each asset must be under 2 GiB; check the actual signed RPM size.
The builder uses Qubes' zstd level 19 payload compression. Larger variants need
another RPM host. Do not split RPM files and call them a native repository.

## Native repository with GitHub-hosted RPMs

Host small RPM metadata on GitHub Pages and RPM payloads on GitHub Releases.
The metadata's base URL points at that release's assets. This avoids putting
multi-gigabyte RPMs in Git or a Pages site.

With signed RPMs in `artifacts/`, from the publishing shell:

```sh
mkdir -p artifacts/rpm-repo
cp artifacts/*.rpm artifacts/rpm-repo/
createrepo_c \
  --baseurl https://github.com/cuzrawr/qubes-nixos/releases/download/v0.1.0/ \
  artifacts/rpm-repo
gpg --local-user YOUR_KEY_FINGERPRINT --armor --detach-sign artifacts/rpm-repo/repodata/repomd.xml
```

Copy only `repodata/` into `repository/rpm/r4.3/x86_64/`, together with the public
key and client files already in `repository/`. The Pages workflow publishes that
directory after verifying its metadata signature. Publish the exact same signed
RPMs under that release. For later
versions, rebuild metadata pointing to the new release; preserve old release
assets for users who need them.

For an ordinary HTTPS server, upload the complete `artifacts/rpm-repo/` directory
and omit `--baseurl` when generating metadata. Keep the RPMs beside `repodata/`.
These methods use the same native Qubes client configuration.

### Configure the client

In a transfer qube, download the public key and this `.repo` definition, using
the publisher's actual URL:

```ini
[qubes-nixos]
name=NixOS templates for Qubes 4.3
baseurl=https://cuzrawr.github.io/qubes-nixos/rpm/r4.3/x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file:///etc/qubes/repo-templates/keys/RPM-GPG-KEY-qubes-nixos
```

Verify the fingerprint through a trusted channel. Copy the files to dom0 using
`qvm-run --pass-io`, as for a local RPM, then install them in dom0:

```sh
sudo install -Dm644 template-key.asc \
  /etc/qubes/repo-templates/keys/RPM-GPG-KEY-qubes-nixos
sudo install -Dm644 qubes-nixos.repo /etc/qubes/repo-templates/qubes-nixos.repo
qvm-template --repoid=qubes-nixos --refresh list --available
qvm-template --repoid=qubes-nixos install nixos-26.05-xfce
```

Use `nixos-unstable-xfce` for unstable. Qubes Template Manager can then use the
configured repository too. Downloads run through the normal UpdateVM.

For a one-time repository selection, keep the key in the same key directory and
use the downloaded `.repo` file without installing it:

```sh
qvm-template --repo-files ./qubes-nixos.repo --refresh list --available
qvm-template --repo-files ./qubes-nixos.repo install nixos-26.05-xfce
```

`qvm-template upgrade TEMPLATE` replaces a template from its repository;
`reinstall` reinstalls its packaged version. These replace root contents,
including `/etc/nixos`, and differ from an in-template NixOS update. Back up the
configuration or install a separately named replacement first.

Removing the `.repo` file stops future repository use. It does not remove
templates. Remove them with `qvm-template remove TEMPLATE`, after switching
dependent qubes to another template.

## Official community repository

Publishing on GitHub does not add a template to Qubes' community repository.
That requires acceptance into the Qubes build and signing process. Until then,
the local RPM and explicitly configured third-party repository are the paths
provided here. No changes to Qubes' template manager are required.

References: [Qubes templates](https://doc.qubes-os.org/en/latest/user/templates/templates.html),
[qvm-template](https://doc.qubes-os.org/projects/core-admin-client/en/latest/manpages/qvm-template.html),
[GitHub release limits](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases),
[Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).
