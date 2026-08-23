# up

`up` is an x86_64 Fedora 44 Atomic desktop image derived from Universal Blue
Silverblue. It targets a personal GNOME workstation used for gaming, desktop
applications, and libvirt/QEMU virtualization. The host stays image-managed:
RPMs and defaults are composed into `/usr`, managed GUI applications are applied
as per-user Flatpaks, and development tools belong in containers.

## Architecture

```text
GitHub pull request ─→ tests ─→ container build ─→ bootc lint (no publication)
GitHub main/schedule ─→ tests ─→ container build ─→ bootc lint
                                               └─→ GHCR tags ─→ Cosign digest signature
Universal Blue Silverblue (digest pinned)
  ├─→ Universal Blue OGC kernel artifact (digest pinned)
  │    └─→ replace Fedora kernel during image composition
  └─→ RPM customization + image-owned /usr defaults
       ├─→ boot-time dconf database compilation
       └─→ login-time application of changed Flatpak configuration
```

The `Containerfile` runs only while composing an image. `build.sh` reads
`packages.json`, installs requested RPMs, and removes only explicitly named,
installed exclusions. `usr/` becomes image-owned content. The system dconf unit
runs at boot; the Flatpak user unit runs after login, reapplies the managed
configuration only when its inputs change, and retries transient failures.
GitHub Actions validates all events, but only trusted default-branch
builds receive registry credentials, production tags, and signatures.

## Open Gaming Collective kernel

This image replaces Fedora's stock kernel at composition time with the Open
Gaming Collective (OGC) kernel from Universal Blue's prebuilt
`ghcr.io/ublue-os/akmods:ogc-44` OCI artifact. Both the Silverblue base and OGC
artifact are digest-pinned. Renovate proposes and, after required CI succeeds,
automatically merges digest-only updates for these two trusted Universal Blue
streams. Only the OGC kernel RPMs are consumed: this does not turn the image
into Bazzite or add
Bazzite services, branding, sessions, schedulers, or extra kernel modules.

Check the running kernel after booting the image:

```bash
uname -r
```

The release should have the form `*-ogc*.fc44.x86_64`. The installer discovers
the kernel family from RPM metadata, including every supplied
`kernel-modules-*` and `kernel-devel-*` subpackage. It fails unless all selected
packages are OGC Fedora 44 builds of one release, all required components are
present, and no unrelated kernel-family RPM remains after installation. The
exact installed package list is recorded in
`/usr/share/up/ogc-kernel-packages` for CI verification.

### Secure Boot

Universal Blue signs the OGC kernel with its kernel-signing certificate. The
pinned Silverblue base already includes that certificate at
`/etc/pki/akmods/certs/akmods-ublue.der`; its subject is `CN=ublue kernel`. The
certificate still must be trusted by the machine's UEFI/MOK database. Existing
Universal Blue installations that previously enrolled the same key do not need
to enroll it again.

Check Secure Boot and key enrollment without changing the machine:

```bash
mokutil --sb-state
sudo mokutil --test-key /etc/pki/akmods/certs/akmods-ublue.der
```

If Secure Boot is enabled and the key is not enrolled, firmware/shim will refuse
to boot the OGC kernel. Do not disable Secure Boot. Follow Universal Blue's
documented MOK enrollment procedure, or retain the previous deployment and use
the rollback commands below. This repository does not enroll keys automatically.

## Features and package policy

- Gaming: Steam, Gamescope, GameMode, MangoHud, vkBasalt, Vulkan/OpenXR tools,
  controller udev support, and required i686 graphics/audio compatibility.
- Virtualization: libvirt, QEMU/KVM, and virt-manager. Group membership and
  libvirt network activation remain administrator choices.
- Desktop: dark GNOME defaults, flat mouse acceleration, Inter and JetBrains
  Mono fonts, a checksum-pinned Tela icon theme, and a curated favorites list.
- Flatpaks: Zen Browser, Discord, Heroic, Bottles, Celluloid, Moonlight, Pods,
  and Flatseal from the per-user Flathub remote.

`rEFInd` is intentionally retained for machines whose operator wants that boot
manager; installing it in the image does not automatically replace the active
bootloader. `toolbox` is intentionally excluded, so use Distrobox or remove that
exclusion if Toolbox is desired. See `packages.json` for the authoritative list.

## Install, update, and recover

Inspect the current deployment first with `sudo bootc status`. Switch with:

```bash
sudo bootc switch ghcr.io/letabouret/up:latest
sudo systemctl reboot
```

New images are normally staged by the system's bootc update mechanism. To
request one explicitly, run `sudo bootc upgrade` and reboot. To roll back:

```bash
sudo bootc rollback
sudo systemctl reboot
```

The previous deployment is also selectable from the bootloader. For deeper
recovery, boot it and switch to a known history tag or digest, for example
`ghcr.io/letabouret/up:44-YYYYMMDD-abcdef0`.

### Verify an image

CI signs the immutable manifest digest with the repository's existing Cosign
key. Verify a published digest (preferred) or tag with:

```bash
cosign verify --key cosign.pub \
  ghcr.io/letabouret/up@sha256:REPLACE_WITH_DIGEST
```

Signing proves publication by the holder of `SIGNING_SECRET`; it does not by
itself make the installed host enforce that key. Strict bootc container policy
is deliberately not enabled because it requires planned key rotation and
recovery. Never commit `cosign.key`.

## Development

- Change RPMs in `packages.json`. Removal has a 50-package safety ceiling.
- Change desired applications in `etc/flatpak/user/{install,remove}`. A
  content hash triggers configuration application and is recorded only after success.
  The install list ensures apps are installed when this configuration changes;
  the remove list explicitly removes apps then. Unlisted apps and later user
  choices are otherwise unmanaged, so the service does not fight user changes
  on every login. The manager script and Flathub remote definition are also
  included in the state hash.
- Change GNOME defaults in `etc/dconf/db/local.d/01-ublue`.
- Run `tests/validate.sh` before committing (requires `jq`, ShellCheck, shfmt,
  Bash, and optionally systemd tools).
- Build with `podman build -t up:dev -f Containerfile .`; the final layer runs
  `bootc container lint`.

Pull requests validate and build without publishing. Other events publish only
from the repository default branch. History tags combine Fedora version, UTC
date, and short Git SHA; `44` and `latest` remain moving aliases. Renovate tracks
the Silverblue and OGC artifact digests and immutable GitHub Action references.

### Renovate automerge safety

Renovate PR automerge is limited to digest updates for
`ghcr.io/ublue-os/akmods` and `ghcr.io/ublue-os/silverblue-main`. Tags remain
`ogc-44` and `44`, so moving to Fedora 45 remains a manual, reviewed change.
Renovate does not ignore tests and cannot safely automerge unless GitHub branch
protection for `main` requires these pull-request checks:

- `Static validation and tests`
- `Build pull request image`

Configure those exact check names in GitHub under **Settings → Branches → main
→ Require status checks to pass before merging**. Keep the branch up-to-date
requirement enabled. The first check covers JSON, shell, package, Flatpak, and
OGC static tests; the second builds the complete image, verifies every OGC RPM
listed by the image, and runs `bootc container lint` during the build. A failed
or pending required check therefore leaves the Renovate PR open.

## Third-party content

- Tela Icon Theme 2026-07-07 is downloaded by release tag and verified with the
  SHA-256 in `Containerfile`; its GPL-3.0 license is copied into the image. To
  update it, review the release/install script, compute the archive checksum,
  then update both build arguments together.
- Vendored Inter and JetBrains Mono binaries are OFL-1.1 licensed. Attribution
  is in `THIRD_PARTY_NOTICES.md`. They remain vendored to preserve exact files.

The repository's Apache-2.0 license does not replace upstream asset licenses.

## Important files

| File | Execution time | Role |
| --- | --- | --- |
| `Containerfile` | Image build | Pinned base, customization, bootc lint |
| `install-ogc-kernel.sh` | Image build | Defensive OGC kernel replacement and verification |
| `build.sh` / `packages.json` | Image build | Defensive RPM package configuration |
| `.github/workflows/build.yml` | CI | Validate, build, publish, sign |
| `usr/lib/systemd/system/dconf-update.service` | Boot | Compile dconf defaults |
| `usr/lib/systemd/user/ublue-user-flatpak-manager.service` | Login | Retry changed configuration |
| `usr/libexec/ublue-user-flatpak-manager` | Login | Apply managed Flatpak configuration |
| `etc/modules-load.d/*` | Boot | Preload controller HID drivers |
| `cosign.pub` | Verification | Public half of the signing key |
