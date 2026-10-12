# Minimalism implementation evidence — 2026-10-12

This directory records local static analysis and container-image verification.
It is not VM or gaming-PC runtime evidence. The private machine export is not copied here.
The [implementation report](../../minimalism-implementation.md) contains decisions,
exceptions, service interpretation and deployment blockers.

## Measured results

| Measurement | Before | After | Change |
| --- | ---: | ---: | ---: |
| RPM package instances (keys excluded) | 2,488 | 2,458 | -30 |
| Unique RPM names | 2,310 | 2,280 | -30 |
| RPM declared payload bytes | 8,511,706,763 | 8,357,029,663 | -154,677,100 |
| GNOME-visible image launchers | 26 | 16 | -10 |
| System enabled services | 68 | 67 | -1 |
| User enabled services | 9 | 9 | +0 |
| System enabled timers | 7 | 7 | +0 |
| User enabled timers | 2 | 2 | +0 |
| System enabled sockets | 53 | 53 | +0 |
| User enabled sockets | 4 | 4 | +0 |
| Autostart declarations | 19 | 18 | -1 |
| Merged /usr + /etc + /opt allocated bytes | 9,814,528,000 | 9,655,738,368 | -158,789,632 |
| Compressed OCI layer bytes | 4,455,694,190 | 4,460,575,530 | +4,881,340 |
| OCI layers | 130 | 130 | +0 |
| Configured Flatpak defaults | 8 | 20 | +12 |
| Runtime CPU / RAM / frame times | Not measured | Not measured | Unknown |


33 removed RPM instances and three additions explain the net change of -30.
The additions are GNOME System Monitor, htop and hwloc-libs. No retained RPM version
changed between these two builds. Twelve gpg-pubkey records in each image are
excluded from package counts; raw RPM database rows are 2,500 and 2,470.

Allocation decreases by 151.43 MiB for the measured directories, while compressed
layers increase by 4.66 MiB. The 128 inherited layers are byte-identical between
these local gzip exports and total 4,051,216,837 compressed bytes. The original
registry representation totals 4,051,159,149 bytes; export compression can differ.
Two Up composition layers remain. Whiteouts and changed files in a derivative do
not remove inherited transfer bytes. No flattening, registry publication, guest
boot or Flatpak application downloads occurred.

## Identities and method

Both builds use Bazzite GNOME stable base
`sha256:629fed5385623270d6356a33a483b5a69010be0f5b84a11f27b58558a32b6`.
“Before” is the staged repository snapshot taken before this implementation;
“after” is the final composition. The before tree was copied using checkout-index,
without replacing the user's worktree. Live package repositories were used for
Up additions; these builds do not claim complete bit-for-bit reproducibility.
The labels use local review versions, not release identifiers.

- Before local image ID: `sha256:dfc9b8254261528a86db05be3d172611d76cfa2005c44ac84048faa2c9d4ed12`.
- Before local gzip OCI manifest: `sha256:82ececb00fa502f2690f113848dd9ff45b4e571917f1aee9a96355d8ec625a11`.
- After local image ID: `sha256:ac9c754a31383274ca3e8d8a962550d07db46e0cc102da43297a5dc74d71df34`.
- After local gzip OCI manifest: `sha256:d7eae98cc4a31d146f5e648a85a233a750145fe95a8d0777d5a9f3e37d9d5121`.


These OCI digests describe local exports, not signed release candidates. Exporting
used the local `oci:` filesystem transport; no registry push occurred. The OCI
index entry annotated `latest` was selected, not an older untagged manifest in the
same local layout. Labels and totals are retained in [metrics.json](metrics.json).

Collection used separate offline containers. `rpm -qa` captured NAME, VERSION-RELEASE,
ARCH and SIZE. Unit states came from `systemctl --root=/ list-unit-files` and the
`--global` user-unit equivalent; only state `enabled` is counted as enabled.
Autostarts count desktop files under `/etc/xdg/autostart` and skeleton autostart.
Launchers count `/usr/share/applications/*.desktop` entries with Type=Application,
without Hidden/NoDisplay=true, respecting OnlyShowIn/NotShowIn for GNOME. They do
not model an existing user's overrides, TryExec resolution or runtime app visibility.
System Monitor's KDE-only entry therefore does not count as a duplicate GNOME app.

Filesystem allocation used `du -sx --block-size=1 /usr /etc /opt` in each merged
container root. This excludes persistent home, Flatpak downloads, `/var`, virtual
filesystems and the backing store's retained layers. It is not installed-host disk
usage. RPM SIZE sums are a different payload measure. Compressed totals sum the
selected OCI manifest's layer descriptors, excluding config/manifest overhead;
they are not uncompressed image-inspect sizes or incremental cached download costs.
Before/after version labels, package database updates and initramfs metadata can
also affect the small size delta.

## Files

- [Package delta](package-delta.tsv), complete [before RPMs](before/rpms.tsv) and [after RPMs](after/rpms.tsv).
- [Before system units](before/system-units.txt), [after system units](after/system-units.txt), [before user units](before/user-units.txt), [after user units](after/user-units.txt).
- Before/after directories also contain desktop entries, autostarts, filesystem allocation and resolved uupd configuration.
- [Approved 33-package solver plan](removal-transaction.json); [blocked ModemManager plan](modem-removal-transaction.json); [blocked iSCSI plan](after/iscsi-plan.json).
- [Dependency/script checks](dependency-exceptions.txt), [integration details](integration-checks.txt), [Flathub ID checks](flatpak-id-check.json), [verified base signature](base-signature.json).
- [Final build log](build.txt), [before build log](build-before.txt), [offline image smoke](image-smoke.txt), [static validation](static-validation.txt), [actionlint output](actionlint.txt) (empty on success).
- [Composition input hashes](input-sha256.txt), [baseline input hashes](before-input-sha256.txt). Local logs and image storage remain under ignored `.up-build/`; temporary inspection containers were removed.

The removal-plan schema is DNF5 transaction version 1.0. It was stored with repos
disabled and --no-autoremove; only the approved plan was replayed in the image
build. The ModemManager and iSCSI proposals were inspected, never executed.

Strict bootc lint passed 14 checks with one skip under its build-root mode. Static
and smoke results do not establish a successful EFI/rEFInd boot, Secure Boot trust,
Polkit prompts, user session, app launch, update transaction or rollback. QEMU was
available, but usable /dev/kvm and an installed boot test disk were unavailable;
VM and physical verification are explicitly not tested.
