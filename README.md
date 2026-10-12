# Up

Up is a personal Fedora 44 GNOME desktop built on the **Bazzite GNOME desktop**
gaming foundation. It retains Up's dark/Tela appearance, Inter and JetBrains
Mono fonts, flat mouse acceleration, favorite applications, virtualization tools
and per-user Flatpaks. Bazzite maintains the kernel, graphics drivers, multilib
libraries, Steam integration and controller support.

The base is digest-pinned. Fedora-major changes and all base updates require
review. Up does not maintain a separate kernel installer, Mesa patch set or Deck
session. Steam stays native RPM; no speculative GPU or scheduler flags are added.
This refactor is not a claim of improved FPS or a confirmed Steam UI fix.

## Documentation

**Production status: not ready for the gaming PC.** rEFInd boot/update/recovery
and the first-boot hardware setup still require validation. Approved minimalism
changes are implemented and locally built; deployment is not authorized.

- [Final implementation, measurements and blockers](docs/minimalism-implementation.md)
- [Current application defaults](docs/application-inventory.md)
- [Architecture and original functionality inventory](docs/architecture.md)
- [Bazzite comparison, decision and source revisions](docs/bazzite-comparison.md)
- [Gaming stack and hardware policy](docs/gaming-stack.md)
- [Steam UI diagnostics and controlled comparisons](docs/steam-troubleshooting.md)
- [Migration, signature enforcement, Secure Boot and rollback](docs/migration.md)
- [Verification results and hardware checklist](docs/verification.md)

Read the migration guide before deploying. **GameMode launch prefixes need review**;
Bazzite removes GameMode. Existing home and `/etc` overrides can survive an OS
change. No host deployment is performed by repository build scripts.

## Development

```bash
tests/validate.sh
podman build -t localhost/up:dev -f Containerfile .
tests/image-smoke.sh localhost/up:dev
```

Validation requires Bash, jq, ShellCheck, shfmt, Python 3, PyYAML and Node.js. Build scripts
are image-composition scripts; never run `build.sh` or `customize.sh` on a host.
Use `packages.json` for personal RPM additions/removals, `etc/dconf` for GNOME
defaults and `etc/flatpak/user/{install,remove}` for managed apps. The Flatpak
manager acts when configuration changes, retries failures, leaves unlisted apps
alone and preserves user remotes. It does not grant blanket filesystem access.

CI verifies the upstream signature, builds and checks the complete image.
Default-branch builds push a unique candidate tag and sign and verify its digest.
After VM and rEFInd hardware gates pass, manually run **Promote tested image**
with that exact digest and the validation attestation to advance `44` and `latest`. Configure `SIGNING_SECRET` to match `cosign.pub` and
require **Static validation and tests** and **Build and verify image** before
merging. Never commit a private key. OCI signatures and UEFI Secure Boot protect
different parts of the system; see the migration guide for both.

Renovate proposes Bazzite digest and action updates; no base automerge is enabled.
Review the changed upstream services, repositories and release before promotion.
Daily builds do not themselves update a digest pin. Live personal-package RPM
repositories, Flatpaks and Steam still evolve, so complete bit-for-bit build
reproducibility is not claimed. The image records its composed RPM/repository
inventory under `/usr/share/up/`.

Theme assets remain checksum-pinned in `Containerfile`; see
[third-party notices](THIRD_PARTY_NOTICES.md) for licenses. Existing `rEFInd` is
mandatory and retained. Existing EFI integration must be preserved; no build
script installs or replaces the bootloader.
