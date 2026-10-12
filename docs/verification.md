# Verification and measurement

Run repository checks with `tests/validate.sh` (Bash, jq, ShellCheck, shfmt,
Python 3, PyYAML and Node.js). Build with `podman build -t localhost/up:dev -f Containerfile .`,
then run `tests/image-smoke.sh localhost/up:dev`. Building is not booting.
CI records the build timestamp in OCI metadata; local builds default to an
explicit epoch timestamp unless `IMAGE_CREATED` is supplied. Use adequate disk space for the large base plus build layers. CI resource limits
must be observed on the actual runner; do not delete unrelated host data to fit.

## Final implementation execution — 2026-10-12

The approved changes were built using host Podman through `flatpak-spawn`, with
isolated storage and no host OS changes. Static tests, actionlint, full image
builds, strict bootc lint, offline smoke, protected gaming-stack comparison and
base signature validation passed. VM and physical boot tests remain unperformed.
See the [final report](minimalism-implementation.md) and [measured evidence](audit/2026-10-12-minimalism/README.md).
This supersedes the earlier engine-availability limitation below.

## Earlier independent audit execution — 2026-10-12 (historical)

This later audit supersedes production-readiness conclusions based only on the
2026-10-11 build. The environment is a Flatpak SDK without Podman/Skopeo; prior
`/tmp/up-review` build artifacts are unavailable. No host packages were installed.
Validation tools were downloaded to `/tmp/up-audit`, and no OS/deployment was changed.

| Check | Current result |
| --- | --- |
| `tests/validate.sh` | PASS: Bash/jq, ShellCheck 0.11.0, shfmt 3.12.0, behavioral shell tests, 6 policy tests, 4 diagnostic tests, Polkit JS behavior test |
| Multilib regression | PASS: rejects loss of only libFAudio.i686 while x86_64 remains |
| Polkit regression | PASS: all five protected actions require admin authentication for active and inactive subjects; unrelated actions fall through (mock API, not live polkit) |
| Workflows | PASS: actionlint 1.7.12 including embedded shell checks; static policy covers candidate-only publication and manual exact-digest promotion |
| Pinned base signature | PASS: Cosign 3.1.3, key signature/claims/transparency-log inclusion; wrong Up key rejected |
| Base inventory | Extracted RPM database and static activation links from digest-checked selected layers; full TSV comparisons retained |
| Diff hygiene | PASS: `git diff --check` |
| Changed image build / smoke / strict bootc lint | NOT RUN: no container engine in current environment; prior result does not validate these changes |
| Publication / promotion / final Up signature | NOT RUN |
| VM boot / physical rEFInd boot / gaming / resource measurements | NOT RUN |

Validation output is retained in [the evidence directory](audit/2026-10-12/README.md).
Run a fresh build and smoke test before any VM canary. A successful signature of
the Bazzite base is not verification of a new final Up candidate.

## Automated coverage

- JSON syntax and package declaration policy; disjoint install/exclude sets,
  no duplicate names or competing kernel/graphics declarations.
- Bash syntax, ShellCheck and shfmt; behavioral package-removal and Flatpak tests.
- Base digest/variant, action pinning, CI trust boundaries, signature-before-tag
  ordering, manual base review, personal defaults and migration-document contracts.
- Diagnostic privacy and unavailable/timeout handling tests.
- Full build: package resolution, inherited RPM dependency consistency, Fedora
  major, GNOME/GDM/session files, Steam launcher, multilib graphics, gaming tools,
  SELinux configuration, public key presence, managed services and dconf.
- Kernel/initramfs artifacts and required dracut modules; `bootc container lint`.
- Offline final-image smoke test and OCI label checks; compare protected gaming
  RPM versions and the kernel binary hash against the pinned upstream image.
- Virtualization tmpfiles declarations and build-state cleanup; bootc lint uses
  `--fatal-warnings`.
- CI verifies the pinned upstream image signature; trusted publication signs and
  verifies the Up candidate; separate manual promotion verifies the tested digest
  after operator attestation of VM/hardware gates. PR builds do not publish.

No automated container check proves firmware trust, a working display/session,
suspend, input handling, successful boot, update origin or recovery. Image
package versions are recorded, but live RPM repos and Steam/Flatpak updates mean
full bit-for-bit reproducibility is not claimed.

## Execution record

Executed **2026-10-11**, in the separate Ubuntu 24.04 coding environment, using
rootless Podman with storage and runroot under `/tmp/up-review`. No gaming-PC
state was collected. No OS was deployed, no image published, and no host package,
service, firmware or bootloader configuration was changed.

| Check | Result |
| --- | --- |
| `tests/validate.sh` | PASS: Bash syntax, ShellCheck 0.9.0, shfmt 3.8.0, jq; package-removal/Flatpak/JSON behavior; 6 repository-policy and 4 diagnostic tests |
| Workflow validation | PASS: actionlint 1.7.12, including embedded shell checks |
| Upstream signature | PASS: Cosign 3.1.3, pinned Bazzite public key, legacy-format signature; claims and transparency-log inclusion verified |
| Wrong-key negative check | PASS: the same Bazzite digest was rejected using Up's different public key |
| Full image build | PASS: `localhost/up:review`, x86_64, final local image ID `982e1bff8fdf577bed2e1d4342fc5e84ffec9e491c08bbd7b208f6b491111bf8` |
| Systemd units | PASS: system and user units verified separately in their correct contexts |
| Bootc strict lint | PASS: `--fatal-warnings`, 14 passed, 1 conditional skip, zero warnings |
| Offline image smoke | PASS: packages/dependencies, GNOME/session/Steam integration files, service masks, key policy, SELinux config, assets, initramfs, diagnostic CLI and OCI labels |
| Base versus Up comparison | PASS: protected gaming-package versions and kernel binary SHA-256 unchanged from pinned Bazzite |
| Diff hygiene | PASS: `git diff --check` |
| Publication and Up release signing | NOT RUN: production credentials and registry publication were not exercised |
| VM boot / physical hardware / performance | NOT RUN: no local QEMU/KVM boot harness or gaming PC available; use manual gate below |

The image ID above identifies a **local container**, not a published registry
digest suitable for deployment. Logs/artifacts from this run are under
`/tmp/up-review/{build-final.log,image-smoke.log,static-validation.log,base-key-signature.json}`.
The tested smoke invocation was:

```bash
PODMAN_ROOT=/tmp/up-review/storage PODMAN_RUNROOT=/tmp/up-review/runroot \
  tests/image-smoke.sh localhost/up:review
```

Observed versions: kernel `7.2.8-ogc5.1.fc44.x86_64`; Mesa `26.2.4-1.fc44`
(both architectures); GNOME Shell/Mutter `50.5-1.fc44`; GDM `50.3-1.fc44`;
Steam bootstrap RPM `1.0.0.87-5.fc44`; XWayland
`24.1.11.bazzite.0.0.git.7700.2d6aa7f1-1.fc44`; Gamescope
`3.16.31^2-1.fc44`; PipeWire `1.6.9-1.fc44`; Terra WirePlumber
`0.5.17-1.fc44`. The Steam client downloaded later can have a different version.

**Resolved initial failures/findings:** the first verifier assumed Fedora's
WirePlumber package name instead of Terra's; default Cosign 3 verification looked
at keyless provenance rather than the legacy key signature; transient image
`/var` state caused lint warnings; combined system/user unit verification caused
an ordering warning. These were corrected and the final build/smoke checks passed.
A missing build-time `/var/roothome` was also corrected for initramfs generation.

**Residual build notices:** upstream GNOME schemas report deprecated paths and
an ignored `picture-uri-dark` screensaver override; dracut reports unavailable
container syslog logging. Neither failed composition. They are distinct from the
zero-warning **bootc lint** result and do not demonstrate desktop runtime health.
No unresolved local automated failure remains.

For GitHub, replace the old required `Build pull request image` status check with
`Build and verify image`, retaining `Static validation and tests`. Hosted runner
disk capacity, registry credentials, signing-key match and tag promotion still
need their first real CI run.

## Manual release gate (VM, then primary hardware)

| Check | Procedure and acceptance criterion | Result |
| --- | --- | --- |
| Boot / Secure Boot | Boot with enrolled key and enforcing SELinux; verify matching kernel/modules and no failed essential services | NOT RUN |
| Desktop | GDM → GNOME Wayland; verify Up favorites, fonts, theme, flat mouse profile; no unsolicited setup rewrite | NOT RUN |
| New + existing user | First-login Flatpaks, second-login no-op, network-failure retry; preserve existing user choices and remotes | NOT RUN |
| Steam | RPM launcher opens; no duplicate system/user Flatpak ambiguity; client build recorded | NOT RUN |
| Steam UI | Five startup timings and scripted manual resizing from troubleshooting guide; no artifacts or stalls | NOT RUN |
| Multi-monitor | Single/integer baseline, mixed refresh/scale, repeated moves/maximize/resize; no compositor crash | NOT RUN |
| Vulkan / acceleration | `up-steam-diagnostics --graphics`; RX 7900 XTX RADV hardware renderer, not llvmpipe/lavapipe | NOT RUN |
| Proton | One representative DX11 and one DX12 game, fixed Proton version; controller, audio and overlay optional | NOT RUN |
| Frame pacing | Repeat identical benchmark/scene 3–5 times; compare distributions, not one run | NOT RUN |
| VRR / HDR | Confirm display/session capability; test separately in fullscreen and borderless; no unqualified support claim | NOT RUN |
| Audio / input | Wired/Bluetooth controllers and Steam Input; check audio dropout/underrun while gaming | NOT RUN |
| Suspend | Five suspend/resume cycles, including Steam open and displays attached; audio/display/input recover | NOT RUN |
| Virtualization | Start an existing VM without changing network/groups automatically; confirm storage access | NOT RUN |
| Update | Stage a second signed Up digest with enforced policy; reboot; confirm custom origin and persistence | NOT RUN |
| Rollback | Select previous/pinned entry and CLI rollback; verify old OS plus persistent home/var behavior | NOT RUN |
| Negative signature | Reject unsigned/wrong-key candidate in disposable VM with enforcement; never use daily driver for this test | NOT RUN |

Test on a disposable VM first for boot/update/policy lifecycle. Do not claim that
VM graphics represents the RX 7900 XTX. A full Fedora release change also needs
application-data compatibility review and rollback rehearsal.

## Performance baseline protocol

Before deployment, preserve a baseline on the old Up image using the same monitor
layout, Steam/client channel, Proton, game build, resolution, quality, FPS cap,
power profile, VRR/HDR and background workload. Record those variables and the
image digest. Keep downloads and background shader processing consistent; record
when they are active. Alternate old/new runs where practical to reduce drift.

Measure startup from launch action to an interactive library (five trials), UI
artifact counts and longest stall in the fixed 30-second resize test. For games,
use the same benchmark or reproducible scene (3–5 runs after warmup), recording
frame times via MangoHud. Preserve raw frame-time data. State the convention for
1% lows (for example inverse of mean of the slowest 1% frame times); do not confuse
it with the inverse 99th percentile. Report median run average FPS, 1% lows,
p95/p99 frame time, run-to-run spread and visible stutters. Treat cold shader
compilation and warm-cache play as separate experiments, without routinely
wiping caches. Keep logs private until reviewed.

Sample CPU/GPU utilization and memory pressure during the same workload, using
available tools and `/proc/pressure/{cpu,memory,io}`. Record RAM/swap usage and
background-service count. A lower service count alone is not a performance win.
Use `systemctl --type=service --state=running` and its user equivalent privately;
service names can reveal installed software. Avoid global clocks/scheduler tweaks
during baseline collection.

Record failures as well as successes. No benchmark numbers currently exist for
this change. The acceptance target is stable function without reproducible
regression; any numerical performance threshold must exceed measured test noise.


## Follow-up priorities

1. **Highest benefit:** collect the old Up baseline on the actual gaming PC and
   reproduce the Steam resize problem with the controlled display/CEF matrix.
   This supplies the missing evidence before claiming a fix or performance gain.
2. **High benefit:** add disposable VM boot, enforced-signature negative testing,
   update and rollback to required CI; then run the hardware canary. Container
   success cannot establish those properties.
3. **Moderate benefit:** after stable operation, measure background services and
   review optional inherited software. Reduce footprint only where functionality
   and dependency testing support it; benchmark before enabling optional tuning.
4. **Maintenance:** review Cosign/containers-image signature-format migration,
   Fedora-major transitions, reproducible RPM inputs and key-rotation recovery.
