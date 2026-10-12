# Evidence ledger — 2026-10-12

Start with the [final implementation report](../../minimalism-implementation.md)
and [current application selection](../../application-inventory.md).

The machine-specific audit, `evidence.json` (including raw inventory hashes),
`rpm-comparison.tsv` and `service-comparison.tsv` are local-only and Git-ignored.
The files below describe public upstream image contents or repository validation.

- `bazzite-rpms.tsv`: all 2,348 RPM database records from the pinned base, including
  12 public-key records. RPM header installed bytes are not compressed image size
  or measured disk/RAM use.
- `bazzite-desktop-owners.tsv`: 54 RPM owners with application files in the RPM
  manifest; desktop visibility and post-install file removal are not inferred.
  Direct-name reverse requirements are not a complete dependency solver result.
- `bazzite-enable-links.tsv`: static `/etc/systemd` wants/requires links and the
  display-manager alias extracted from the base's unpackaged-content layer.
  These include masked/conditional units and are not a running-service inventory
  or equivalent to `systemctl list-unit-files` on a deployed system.
- `static-validation.txt`: actual final repository test output from this audit.

## Retrieval and interpretation

Registry manifest and config were retrieved from GHCR for
`sha256:629fed5385623270d6356a33a483b5a69010be0f5b84a11b91f27b58558a32b6`.
The sum of all 128 manifest layer sizes is 4,051,159,149 compressed bytes. The
image config reports source revision `a9450099562e12e4ea0da19efcdefe6e284ffcdb`.
The 2026-10-12 upstream main revisions were Bazzite
`b6c6d4cff61aa801ee52afbe9a625cfb4a9f938d` and Universal Blue main
`b6639588bebf0c060de0e04af8d2e7a553a42942`. These are comparison
references, not substitutes for the published image revision.

Selected layers were downloaded into memory and checked against their SHA-256
descriptors; no image was installed or run. The RPM component layer is
`sha256:41c7afe09b5afde82ea8265fde190c196d8b7f7a3220afdf913f6e05a770a424`.
Its `usr/share/rpm/rpmdb.sqlite` hardlink was resolved to the OSTree object in the
same tar archive. Read-only Python SQLite access and RPM header tags
NAME/VERSION/RELEASE/ARCH/SIZE/REQUIRENAME/BASENAMES/DIRNAMES/DIRINDEXES supplied
package and desktop-file records. Public-key records lack ARCH and use `(none)`.
This reads the base database, not the separate rpm-ostree-base-db in another layer.

Activation links were read from
`sha256:2bb237d0ce0192d508e9ffa20731b525b27734bd137c3975f7eb74fb0d4cd726`,
resolving tar hardlinks to OSTree symlink objects. The base masks
`fedora-atomic-desktop-appstream-cache-refresh.service`, `iscsi.service` and
`systemd-remount-fs.service`; a wants link can coexist with a mask. Final Up adds
its own masks and virtualization dependencies, so this is not an exact final
service count. Re-query the built image and then the running canary.

Fresh Cosign 3.1.3 verification of the pinned base passed using `keys/bazzite.pub`
and `--new-bundle-format=false`, including claims, signature and transparency-log
inclusion checks. Verification with `cosign.pub` failed for the wrong key. No
cryptographic check was disabled. The signature format emits a deprecation notice.
Temporary source snapshots, retrieval scripts, RPM database and signature output
were kept under `/tmp/up-audit`; they may disappear between sessions.

## Reproduce the final-image comparison later

In a container-capable builder, run the repository's full build and
`tests/image-smoke.sh IMAGE`. Save `podman image inspect IMAGE`, the composed
`/usr/share/up/packages.txt`, `/usr/share/up/enabled-repositories.txt`, and offline
`systemctl --root=/ list-unit-files` results for both scopes. Compare complete
`NAME.ARCH`/version records as well as the protected stack. Measure a published
candidate's compressed manifest separately; Podman's local size and RPM header
payload sizes are different quantities. Capture `systemctl` running units and
resource samples only from the VM/physical canary, labeled by host and workload.

A new image build, VM boot, hardware boot, actual Up signature, publication,
promotion, or resource benchmark was not performed in this audit.
