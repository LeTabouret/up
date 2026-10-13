# Migration and recovery

**Repository changes are not a deployment.** These commands are for the owner to
review and run later on the gaming PC. Nothing in this work rebases, reboots,
enrolls keys, modifies host services, or installs a bootloader. Complete CI and
the manual canary in [verification](verification.md) before daily-driver use.

## Publication approval

The Silverblue → Bazzite migration is not automatically promoted. Keep
`BAZZITE_AUTO_PUBLISH_FEDORA` unset until the exact candidate passes the manual VM
and hardware checklist and the owner explicitly approves the migration. Then run
**Promote tested image** with that Up digest and the validation attestation; only
afterward set the repository Actions variable to `44`. Subsequent successful daily
builds publish same-major Bazzite updates automatically. CI also requires an
already signed Bazzite Fedora 44 `latest`, so setting the variable prematurely
cannot replace Silverblue. See [the workflow details](../README.md#development).

For a later Fedora-major migration or an exceptional release, remove the variable
first, review any required major guards, validate a candidate manually, and use
**Promote tested image** again. Re-enable daily publication only for the validated
major. CI does not perform or attest to the hardware checks below.

## Actual machine preflight — required before the generic procedure

Read the current machine state before migration. Identify the booted known-good
deployment, any pending deployment, the update origin and active OS/Flatpak update
timers. Do not assume deployment index 0 is the booted system. Machine-specific
digests and historical deployment indices remain in the private local records.

From the real host terminal, collect these read-only checks privately:

```bash
sudo bootc status --json
rpm-ostree status --json
sudo ostree admin status
rpm-ostree kargs
mokutil --sb-state
sudo efibootmgr -v
findmnt /boot
findmnt /boot/efi
systemctl cat bootloader-update.service
sudo bootupctl status
systemctl list-timers --all
systemctl --user list-timers --all
```

Use the installed tool's supported status syntax if an option is unavailable.
The earlier `bootc status` permission error is not proof that conversion is
unsupported. Existing OSTree systems can be converted, but local layering or
initramfs modifications may prevent bootc updates; do not erase them with a blind
reset. See [bootc installation](https://bootc.dev/bootc/bootc-base-images.7.html)
and [local initramfs limitations](https://bootc.dev/bootc/initramfs.html).

Before a staging command, back up the ESP and rEFInd configuration along with
home, `/etc` and VM/game data. Record BootOrder and the working boot path. Confirm
whether rEFInd chainloads shim/GRUB or directly loads a kernel; check its scanning
rules and kernel/initramfs arguments. Keep a recovery USB whose boot has been
tested. Do not run `refind-install`, `bootupctl adopt-and-update`, GRUB installation,
EFI-entry writes, or key-enrollment commands without the owner's explicit approval.

Pin the **booted known-good entry identified by the new status**, not a hardcoded
index. Review any already-staged update deliberately; do not casually reboot or
clear it. During the future maintenance window, record and temporarily stop the
active OS-update timer before staging so it cannot race the candidate operation;
retain the original timer state for recovery. Only do this as an intentional
owner-run migration action. This audit has not stopped any timer.

**Critical first-boot behavior:** inherited `bazzite-hardware-setup.service` runs
before user sessions, can append `bluetooth.disable_ertm=1`, remove `nomodeset`,
apply hardware-specific changes, and calls `reboot` when it stages needed arguments.
A digest pin does not prevent this local setup reboot. Review the existing kargs
and rehearse the behavior in a disposable VM before the hardware canary. Do not
silently patch or disable the service: that changes boot behavior and needs review.
Greenboot's automatic rollback must also be tested through the actual rEFInd path.

## Compatibility changes to review

- GNOME, dark/Tela/font/mouse defaults, favorites, virtualization and the selected
  user Flatpaks remain. The final manifest declares 20 defaults. GNOME Terminal/Software are explicitly installed because
  Bazzite normally uses alternatives. Saved user preferences override defaults.
- Steam stays native. Bazzite's launcher becomes the desktop entry and supplies
  Wayland Steam Input integration. Existing local desktop launchers may bypass it.
- **GameMode** is no longer installed, matching the upstream Bazzite build. Remove
  `gamemoderun` from per-game launch options before testing. Do not substitute
  scheduler/clock overrides. Gamescope/MangoHud/vkBasalt remain available.
- Bazzite adds upstream software and services. Its automatic user setup and
  global Flatpak manager and optional dmemcg performance booster are masked; no blanket Flatpak permission grants occur
  through those services. An already-installed Flatpak Steam is not deleted.
- Up's Flatpak manager now preserves existing remotes. It ensures the 20
  declared apps on configuration changes, skipping apps already installed in
  either user or system scope, and respects later user choices between changes.
  Moonlight and on-demand apps are never automatically uninstalled. Existing
  duplicates are preserved; review them manually. Old per-user Portal autostarts
  may remain after its RPM is removed; review those entries without deleting data.
- Old `/etc` files and user environment/desktop overrides can survive migration.
  Check dconf profile/database, custom sysctls, repos, module configuration and
  service masks. Do not copy a whole old `/etc` over the new image or reset all
  user settings. Back up and reconcile only files that differ deliberately.

## Prepare and verify

1. Back up home, game saves, local-only Proton prefixes, VM storage and essential
   `/etc`. `/var` and home are shared across OS deployments; rollback does not
   restore them. Record `bootc status`, `rpm-ostree status`, exact old image digest,
   current kernel arguments and active updater timers privately. Check free
   space in `/var`, `/boot` and the ESP. Bazzite is a large image.
2. Confirm that root `bootc status` recognizes the booted image and reports no
   incompatible local changes. Rehearse the switch from this rpm-ostree-origin
   system in a VM using matching installed tool versions. If bootc does not
   recognize it, stop before staging and resolve that specific incompatibility;
   do not guess an unverified rebase, reset layers, or reinstall the bootloader.
   After selecting bootc as the update path, avoid competing update transactions.
3. Keep a known-good boot entry and recovery USB. For an OSTree-backed system,
   inspect `ostree admin status` and deliberately pin the desired deployment
   index with `sudo ostree admin pin INDEX` (substitute its actual index).
   Confirm the pin; do not assume index zero always identifies the desired OS.
4. **Secure Boot:** inspect `mokutil --sb-state` and
   `mokutil --test-key /etc/pki/akmods/certs/akmods-ublue.der`. OCI signatures do
   not enroll the kernel key. The check above covers only the current deployment's
   certificate; compare the verified candidate certificate below too. If the
   candidate uses an untrusted signing key,
   follow the [Bazzite Secure Boot procedure](https://docs.bazzite.gg/General/Installation_Guide/secure_boot/)
   from the still-trusted previous deployment and test it before relying on the
   new deployment. Keep Secure Boot enabled; do not use the guide's temporary
   disable/re-enable suggestion.
   Installing the retained rEFInd RPM does not make its unsigned EFI executable
   trusted and does not authorize replacing the current bootloader.
5. Obtain the **Up candidate digest** from successful CI, not the Bazzite base
   digest. Confirm the repository's `cosign.pub` fingerprint using your trusted
   checkout and verify the published candidate:

```bash
cosign verify --key cosign.pub --new-bundle-format=false ghcr.io/letabouret/up@sha256:REPLACE_WITH_UP_DIGEST
```

The old Up policy did not enforce its key. For the first transition, manual
verification of the exact digest is the bootstrap trust step. A failed/missing
signature stops migration; do not bypass it. The new image includes an exact
repository policy using `/etc/pki/containers/up.pub`, and a registries.d entry for
sigstore attachments. Review the merged host policy after first boot before
turning enforcement on. Forks must use their own existing signing key and matching
`IMAGE_REPOSITORY`; CI supplies the repository owner's namespace.

After verifying the Up digest, extract its public kernel certificate without
booting or deploying the image (substitute the same verified digest):

```bash
podman run --rm --network=none --entrypoint cat \
  ghcr.io/letabouret/up@sha256:REPLACE_WITH_UP_DIGEST \
  /etc/pki/akmods/certs/akmods-ublue.der > candidate-ublue.der
openssl x509 -inform DER -in candidate-ublue.der -noout -fingerprint -sha256
mokutil --test-key ./candidate-ublue.der
```

If enrollment is needed, remain on the trusted old deployment and deliberately
use MOK enrollment for this reviewed certificate before attempting the candidate.
Complete enrollment in firmware; do not assume importing a file alone completes
trust, and do not disable Secure Boot.

## Stage the canary

Run only after the preparation above, substituting the verified **Up** digest:

```bash
sudo bootc switch ghcr.io/letabouret/up@sha256:REPLACE_WITH_UP_DIGEST
sudo bootc status
```

Inspect the staged target and retained rollback deployment. Reboot at a suitable
time with `sudo systemctl reboot`. There is no `--apply` in these commands.
A digest-pinned deployment will not advance on `bootc upgrade`; this is useful
while testing. [bootc documents this behavior](https://github.com/bootc-dev/bootc/blob/ba0897da4650cbc05ad368cb90739ba7c3110ddd/docs/src/man/bootc-switch.8.md).

After boot, check the deployed digest, SELinux, Secure Boot, GPU driver, session,
Steam, controller, virtualization and suspend behavior. Inspect image-info to
ensure Up's namespace is used. Inspect `systemctl list-timers --all` and
`systemctl status uupd.timer`: Up keeps Bazzite's uupd, and disables competing
bootc-fetch-apply/rpm-ostreed automatic timers in the image. Existing host overrides
can change that. Updater operation against a custom origin requires a canary.
Bazzite hardware setup can stage Bluetooth or device-specific kernel-argument
changes and reboot at first boot; inspect resulting arguments, service logs and
pending deployment after the complete startup sequence.
Do not use a Bazzite `ujust` rebase/reset recipe to switch Up's source.

Once this exact candidate passes the VM and hardware gates, run the repository's
manual **Promote tested image** workflow with its digest and validation attestation.
That verifies the signature again and advances `44`/`latest` without rebuilding.
Automatic builds publish only candidate history tags. Then confirm the merged container policy has a
`sigstoreSigned` rule for `ghcr.io/letabouret/up` with the correct Up public key
and `matchRepository`, plus its sigstore-attachments registries.d configuration.
Do not replace the full policy with an insecure default. Then select a verified
release channel and enable policy enforcement:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/letabouret/up:44
sudo bootc status
```

This stages whatever **signed** digest the `44` alias currently resolves to;
compare it with the tested candidate before reboot. If the alias has advanced,
stay pinned and test that newer digest first. Explicit `44` is preferred over
`latest` for release intent, while the build also rejects an unexpected Fedora
major. Check that old `flatpak-system-update.timer` and `flatpak-user-update.timer` have
not survived alongside uupd's equivalent update modules; reconcile deliberate
overrides instead of scheduling duplicate updates. Only uupd should orchestrate
OS updates; verify rpm-ostreed-automatic and bootc-fetch-apply timers are inactive.
A later update can be requested with `sudo bootc upgrade`; reboot separately
after checking status. Failed signature verification is a failure to resolve,
not an invitation to disable verification.

## Roll back

If the new image will not boot, select the pinned/previous deployment from the
bootloader. For a bootable but faulty candidate:

```bash
sudo bootc rollback
sudo bootc status
sudo systemctl reboot
```

If recovery is performed from the old rpm-ostree-managed deployment instead,
use that deployment's supported `rpm-ostree rollback` procedure, inspect status,
and reboot separately. Do not alternate rollback tools on the same pending
transaction. Selecting the pinned known-good entry through rEFInd is the first
recovery path when the candidate does not reach a usable system.

Do not use `--apply` unless immediate reboot is intended. Coordinate rollback
with the active updater: pause its timer during diagnosis only if needed, record
that action, and re-enable it after selecting a fixed signed image. Otherwise a
moving channel may restage the broken image. A known-good immutable Up digest is
the most explicit recovery target. The previous deployment has its previous
`/etc`; home and `/var` changes remain. Restore user data from backups separately
if an application migration needs reversing. Recover image/key-policy mistakes
from the retained known-good deployment, not by disabling SELinux or Secure Boot.
