# GitHub Free

Checked against GitHub documentation on 2026-09-30. Repository visibility: public.

## CI

Workflow: [Check](../.github/workflows/check.yml).
Triggers: pushes to `main`, pull requests and manual runs.

| Check | Runs on GitHub |
| --- | --- |
| Nix formatting | Yes |
| Evaluation of stable, unstable and diagnostic flake outputs | Yes |
| Existing path-adaptation tests | Yes |
| Signing helper build and its shell checks | Yes |
| ASCII Markdown | Yes |
| Complete desktop images/RPMs | Local builder |
| Qubes boot, GUI, devices, updates and rollback | Qubes runtime environment |

- Standard public-repository runners: free, unlimited minutes.
- Selected runner: `ubuntu-24.04`; advertised 4 CPUs, 16 GB RAM, 14 GB SSD.
- Image construction needs the closure, image and packaging copies; the stock
  disk allowance is too small for the full image pipeline without runner workarounds.
- Actions are pinned by commit. Repository token permissions: `contents: read`.
- No private signing keys or runtime-test credentials in CI.
- No hosted-runner artifact upload or Nix cache service is required.

Sources: [runner limits](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
[Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

## Distribution

| GitHub feature | Use |
| --- | --- |
| Releases | Signed RPMs, checksums, public key and release notes |
| Pages | Small signed RPM repository metadata and installation files |
| Actions | Check source; deploy already prepared public metadata |
| Git repository | Source, pins, tests and documentation |

- Release assets must each be under 2 GiB. No stated total-release or download
  bandwidth limit. [Release limits](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
- Pages: published site at most 1 GB; soft bandwidth limit 100 GB/month.
  Keep RPM payloads in Releases. [Pages limits](https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits).
- The Qubes GUI requires one-time public-key and `.repo` setup in dom0.
  A GitHub source URL alone is not a template repository.
- Keep signing local. Upload public signatures and public keys only.
- Keep untrusted pull-request jobs isolated from signing and runtime testing.

[Publication and client setup](distribution.md).

## If the repository becomes private

GitHub Free currently includes 2,000 hosted-runner minutes/month, 500 MB of
artifact storage and 10 GB of cache storage per repository. Standard public
runner minutes are free; larger runners are paid. Pages on GitHub Free requires
a public repository. [Billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions),
[plan features](https://docs.github.com/en/get-started/learning-about-github/githubs-plans).
