# Up

Up is a personal Fedora 44 GNOME desktop built on the **Bazzite GNOME desktop**
gaming foundation. It retains Up's dark/Tela appearance, Inter and JetBrains
Mono fonts, flat mouse acceleration, favorite applications, virtualization tools
and per-user Flatpaks. Bazzite maintains the kernel, graphics drivers, multilib
libraries, Steam integration and controller support.

Each build uses a verified upstream digest. Daily builds refresh Bazzite within
Fedora 44; Fedora-major changes require manual review and validation. Up does not maintain a separate kernel installer, Mesa patch set or Deck
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

CI verifies the upstream signature, checks the actual Fedora major, builds and
checks the complete image. The existing daily schedule remains `05 10 * * *`
(10:05 UTC). PRs use the committed base pin and never publish. Default-branch
pushes, manual builds and scheduled builds resolve Bazzite GNOME `stable` once,
verify it, and replace the pin **only in the runner checkout**. Build and smoke
tests use that same digest. If upstream moves off Fedora 44, the run fails before
composition; it does not migrate Fedora or silently reuse an old base.

Successful default-branch builds push a unique candidate tag, then sign and
verify its exact digest. Daily builds can advance `ghcr.io/letabouret/up:44` and
`:latest` automatically after all automated checks pass, but **the initial
Silverblue → Bazzite migration remains manual**:

1. Leave the repository Actions variable `BAZZITE_AUTO_PUBLISH_FEDORA` unset
   while validating the migration candidate in a VM and on the actual hardware,
   following [the release checklist](docs/verification.md).
2. After explicit approval, run **Promote tested image** on the default branch
   with that exact Up digest and the validation attestation.
3. Set `BAZZITE_AUTO_PUBLISH_FEDORA` to `44` in repository Settings → Secrets and
   variables → Actions → Variables. Subsequent successful daily builds publish
   automatically. The workflow also verifies that the existing signed `latest`
   is already Bazzite GNOME on Fedora 44, so the variable alone cannot perform
   the migration. Remove the variable to pause automatic publication.

Keep **Promote tested image** for exceptional releases and future major
migrations, including a validated Silverblue recovery; such a recovery closes
the automatic Bazzite gate again. Before a major migration, disable automatic publication, review the
committed base and Fedora guards (including both workflows), and repeat the
manual validation/promotion before opting in to the new major. Push and manually
dispatched builds remain candidate-only. No approval variable is set by this code.
Configure `SIGNING_SECRET` to match `cosign.pub` and require **Static validation
and tests** and **Build and verify image** before merging. Never commit a private
key. GitHub Actions container checks do not validate real-machine boot, Secure
Boot, GPU gaming or recovery; the hardware checklist remains operator-run.

Automatic and manual promotion use the same digest-preserving registry copy and
release lock. All build, smoke, signature and image-policy checks precede moving
tags; `latest` is updated last. Failed checks leave the last published `latest`
untouched. The two tag writes are not a registry transaction: a copy/network
failure can leave `44` and `latest` temporarily different, but only an already
validated, signed candidate is eligible for either tag. Inspect both digests
before retrying the manual workflow after such a failure.

Renovate still proposes reviewed changes to the committed fallback pin and
action versions; base automerge remains disabled. CI records the resolved base
in the run summary and `org.opencontainers.image.base.digest` label, alongside
the existing source revision and unique candidate version. To reproduce the base
input, check out that source revision, replace the `FROM` digest with the recorded
one, verify its signature, then run the development build and smoke commands.
Live personal-package RPM repositories, Flatpaks and Steam still evolve, so
complete bit-for-bit build reproducibility is not claimed. The image records its
composed RPM/repository inventory under `/usr/share/up/`.

Theme assets remain checksum-pinned in `Containerfile`; see
[third-party notices](THIRD_PARTY_NOTICES.md) for licenses. Existing `rEFInd` is
mandatory and retained. Existing EFI integration must be preserved; no build
script installs or replaces the bootloader.
