# Distribute templates

Public key: [RPM-GPG-KEY-qubes-nixos](../repository/RPM-GPG-KEY-qubes-nixos).
Fingerprint: `4B90 5004 6403 DDD1 B6F1 FCF7 A752 8E30 ED60 389C`.
Published builds: [GitHub Releases](https://github.com/cuzrawr/qubes-nixos/releases).

- Build with the committed lock file; complete [acceptance tests](testing.md).
- Publish the source commit, pins, checksums, public fingerprint and results.
- Increase the RPM `release` in `flake.nix` for replacement builds.
- Never replace a published asset with different bytes.
- XFCE and minimal use the same signing/repository procedure. Select the
  build output and template name from the [README](../README.md#versions).

The upstream template RPM spec supplies a GPLv3+ package label. The contained
components retain their own licenses; this repository's integration source has
no license grant.

KEEP IN MIND:

- Keep private keys outside the repository, build inputs and templates.
- Use a dedicated `GNUPGHOME` for every signing command below.
- Back up keys and revocation certificates offline. Never upload them to GitHub.
- A compromised key requires revocation and a new client trust setup.

## Sign a local build

1. Build the selected RPM from the source checkout.
2. Open the release shell and select a separate signing keyring:

```sh
nix develop .#release
export GNUPGHOME=/path/to/project-signing-keyring
install -d -m700 "$GNUPGHOME"

# For a new working identity; use its printed fingerprint below.
gpg --quick-generate-key 'YOUR_RELEASE_IDENTITY' rsa3072 sign 0
artifacts=../qubes-nixos_tmp/artifacts
mkdir -p "$artifacts"
rpm=qubes-template-nixos-26.05-xfce-4.3.0-2.noarch.rpm
nix run .#sign-template -- YOUR_KEY_FINGERPRINT \
  "result-stable/$rpm" "$artifacts/$rpm"
gpg --armor --export YOUR_KEY_FINGERPRINT > "$artifacts/template-key.asc"
```

- Use the filename produced by your build. v0.1.0 uses release `1`;
  the 0.1.1 source uses `2`.
- Already have a working key? Omit `gpg --quick-generate-key`.
- Repeat signing for each variant. `sign-template` requires an explicit keyring.
- The helper uses packaged RPM configuration; host/user RPM macros are ignored.

## GitHub Releases

Users download signed RPMs in a transfer qube and follow the
[local install instructions](../README.md#install-a-signed-rpm).

1. Create and push the reviewed source tag.
2. Put only that release's signed RPMs in `$artifacts`.
3. Create checksums and a draft release. Use the same signing keyring:

```sh
nix develop .#release
artifacts=../qubes-nixos_tmp/artifacts
tag=v0.1.1
(cd "$artifacts" && sha256sum *.rpm > SHA256SUMS)
gpg --local-user YOUR_KEY_FINGERPRINT --armor --detach-sign "$artifacts/SHA256SUMS"
gh release create "$tag" --draft --verify-tag \
  --title "NixOS templates $tag" --notes-file "$artifacts/release-notes.txt" \
  "$artifacts"/*.rpm "$artifacts/template-key.asc" \
  "$artifacts/SHA256SUMS" "$artifacts/SHA256SUMS.asc"
```

4. Review the draft, then publish it in GitHub.

Each asset must be under 2 GiB. Check the signed RPM's actual size.
The builder uses Qubes' zstd level 19 payload compression.
Larger variants need another RPM host; split RPM files are not a native repository.

## Native repository with GitHub-hosted RPMs

| Content | Location |
| --- | --- |
| Signed RPMs | GitHub Releases |
| Signed metadata, public key and client files | GitHub Pages |
| Metadata's base URL | The matching release's assets |

1. From the same shell, generate metadata for the intended signed RPMs:

```sh
mkdir -p "$artifacts/rpm-repo"
cp "$artifacts"/*.rpm "$artifacts/rpm-repo/"
createrepo_c \
  --baseurl "https://github.com/cuzrawr/qubes-nixos/releases/download/$tag/" \
  "$artifacts/rpm-repo"
gpg --local-user YOUR_KEY_FINGERPRINT --armor --detach-sign "$artifacts/rpm-repo/repodata/repomd.xml"
```

2. Copy only `repodata/` into `repository/rpm/r4.3/x86_64/`.
   Public key and client files are already in `repository/`.
3. Publish the exact same signed RPMs under that release.
4. Commit the public metadata. The Pages workflow verifies its signature before
   publishing `repository/`.

For later releases, rebuild metadata with the new release URL.
Keep old release assets available for recovery.

For an ordinary HTTPS server, upload the complete `$artifacts/rpm-repo/` directory
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

Use the selected template name for other profiles. Template Manager uses this
repository too. Downloads run through the normal UpdateVM.

For a one-time repository selection, keep the key in the same key directory and
use the downloaded `.repo` file without installing it:

```sh
qvm-template --repo-files ./qubes-nixos.repo --refresh list --available
qvm-template --repo-files ./qubes-nixos.repo install nixos-26.05-xfce
```

KEEP IN MIND:

- `qvm-template upgrade TEMPLATE` replaces a template from its repository.
- `reinstall` reinstalls its packaged version.
- Both replace root and clear the TemplateVM's private volume, including
  `/etc/nixos`, `/home` and `/usr/local`. Save needed files outside it first.
- Dependent AppVM private volumes stay separate.
- Post-install resets the template's NetVM to its default.
- An in-template NixOS rebuild does not replace these volumes.

Follow the [backup and upgrade procedure](recovery.md#010-to-011), then check
the template's settings.
Source: [Qubes post-install implementation][postinstall].

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

[postinstall]: https://github.com/QubesOS/qubes-core-admin-client/blob/release4.3/qubesadmin/tools/qvm_template_postprocess.py
