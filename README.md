# Up

Up is a personal Fedora GNOME desktop built on the **Bazzite GNOME desktop**
gaming foundation. It retains Up's dark/Tela appearance, Inter and JetBrains
Mono fonts, flat mouse acceleration, favorite applications, virtualization tools
and per-user Flatpaks. Bazzite maintains the kernel, graphics drivers, multilib
libraries, Steam integration and controller support.

Each build uses a verified upstream digest. Up is published in three channels:

| Tag | Built from | Fedora |
|---|---|---|
| `latest` (rolling) | Bazzite GNOME `stable` | whichever major Bazzite currently ships; moves forward only |
| `stable-45` (alias `45`) | Bazzite GNOME `stable-45` | always 45 |
| `stable-44` (alias `44`) | Bazzite GNOME `stable-44` | always 44 |

Up does not maintain a separate kernel installer, Mesa patch set or Deck
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
pushes, manual builds and scheduled builds build **each channel independently**:
each resolves its Bazzite tag once, verifies it, and replaces the pin **only in the
runner checkout**. Build and smoke tests use that same digest. A `stable-N`
channel fails before composition if upstream ever carries another Fedora major;
`latest` accepts the major Bazzite `stable` carries. One failing channel (for
example a new major that does not pass the image checks yet) does not stop the
others.

Successful default-branch builds push a unique candidate tag per channel, then
sign and verify its exact digest. When the repository Actions variable
`UP_AUTO_PUBLISH` is `true`, scheduled builds then advance each channel's tags
automatically after all automated checks pass:

- `stable-N` and its `N` alias accept only Fedora N images built from `stable-N`.
- `latest` accepts only images built from Bazzite `stable`, and **never moves to an
  older Fedora major than it already has**. When Bazzite moves to a new major,
  `latest` follows on the first night that major passes every check; until then it
  keeps the last good image and the run shows the failure.
- **The initial Silverblue → Bazzite migration remains manual**: automation only
  updates a `latest` that is already a signed Bazzite build of Up, so the variable
  alone cannot perform the migration.

To bootstrap or for exceptional releases, run **Promote tested image** on the default
branch with the exact Up digest, the channel and the validation attestation. Remove
`UP_AUTO_PUBLISH` (Settings → Secrets and variables → Actions → Variables) to pause
automatic publication. Push and manually dispatched builds remain candidate-only.
No approval variable is set by this code.
Configure `SIGNING_SECRET` to match `cosign.pub` and require **Static validation
and tests** and **Build and verify image** before merging. Never commit a private
key. GitHub Actions container checks do not validate real-machine boot, Secure
Boot, GPU gaming or recovery; the hardware checklist remains operator-run. A new
Fedora major on `latest` reaches machines without that checklist: follow
`stable-N` instead to choose when to change majors.

Automatic and manual promotion use the same digest-preserving registry copy and
a per-channel release lock. All build, smoke, signature and image-policy checks
precede moving tags. Failed checks leave the channel's published tags untouched.
The `stable-N` and `N` writes are not a registry transaction: a copy/network
failure can leave them temporarily different, but only an already validated,
signed candidate is eligible for either tag. Inspect both digests before retrying
the manual workflow after such a failure.

To add a Fedora major, add `stable-N` to the `publish` matrix in
`.github/workflows/build.yml` and to the channel options in
`.github/workflows/promote.yml`; drop a channel the same way once Bazzite stops
updating it.

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
