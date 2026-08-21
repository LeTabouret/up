# up

`up` is an x86_64 Fedora 44 Atomic desktop image derived from Universal Blue
Silverblue. It targets a personal GNOME workstation used for gaming, desktop
applications, and libvirt/QEMU virtualization. The host stays image-managed:
RPMs and defaults are composed into `/usr`, GUI applications are reconciled as
per-user Flatpaks, and development tools belong in containers.

## Architecture

```text
GitHub pull request ─→ tests ─→ container build ─→ bootc lint (no publication)
GitHub main/schedule ─→ tests ─→ container build ─→ bootc lint
                                               └─→ GHCR tags ─→ Cosign digest signature
Universal Blue Silverblue (digest pinned)
  └─→ RPM customization + image-owned /usr defaults
       ├─→ boot-time dconf database compilation
       └─→ login-time user Flatpak reconciliation
```

The `Containerfile` runs only while composing an image. `build.sh` reads
`packages.json`, installs requested RPMs, and removes only explicitly named,
installed exclusions. `usr/` becomes image-owned content. The system dconf unit
runs at boot; the Flatpak user unit runs after login and retries transient
failures. GitHub Actions validates all events, but only trusted default-branch
builds receive registry credentials, production tags, and signatures.

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
cosign verify --key cosign.pub --new-bundle-format=false \
  ghcr.io/letabouret/up@sha256:REPLACE_WITH_DIGEST
```

Signing proves publication by the holder of `SIGNING_SECRET`; it does not by
itself make the installed host enforce that key. Strict bootc container policy
is deliberately not enabled because it requires planned key rotation and
recovery. Never commit `cosign.key`.

## Development

- Change RPMs in `packages.json`. Removal has a 50-package safety ceiling.
- Change desired applications in `etc/flatpak/user/{install,remove}`. A
  content hash triggers reconciliation and is recorded only after success.
- Change GNOME defaults in `etc/dconf/db/local.d/01-ublue`.
- Run `tests/validate.sh` before committing (requires `jq`, ShellCheck, shfmt,
  Bash, and optionally systemd tools).
- Build with `podman build -t up:dev -f Containerfile .`; the final layer runs
  `bootc container lint`.

Pull requests validate and build without publishing. Other events publish only
from the repository default branch. History tags combine Fedora version, UTC
date, and short Git SHA; `44` and `latest` remain moving aliases. Renovate tracks
the base digest and immutable GitHub Action references.

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
| `build.sh` / `packages.json` | Image build | Defensive RPM desired state |
| `.github/workflows/build-modern.yml` | CI | Validate, build, publish, sign |
| `usr/lib/systemd/system/dconf-update.service` | Boot | Compile dconf defaults |
| `usr/lib/systemd/user/ublue-user-flatpak-manager.service` | Login | Retry reconciliation |
| `usr/libexec/ublue-user-flatpak-manager` | Login | User Flatpak desired state |
| `etc/modules-load.d/*` | Boot | Preload controller HID drivers |
| `cosign.pub` | Verification | Public half of the signing key |
