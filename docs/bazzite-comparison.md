# Bazzite comparison and evidence ledger

Historical architecture comparison inspected on 2026-10-11. See the
[final implementation report](minimalism-implementation.md) for newer source revisions,
measured inventories and unresolved blockers. No performance measurements were taken on gaming hardware.
Source-tree observations and registry metadata are evidence of implementation,
not proof of runtime behavior or of faster frame times.

## Architecture alternatives

| Dimension | A: Bazzite GNOME desktop (selected) | B: Silverblue plus selected features | C: stock Fedora bootc / custom gaming overlay |
| --- | --- | --- | --- |
| Gaming / Steam | Coordinated upstream kernel, drivers, Mesa, XWayland, Steam wrapper | Up must integrate and test these pieces | Largest integration gap |
| Performance | Plausible consistency benefits; unmeasured | Could be equivalent; kernel alone proves nothing | No demonstrated advantage |
| Maintenance / drift | One base pin; narrow customization | Multiple evolving pins, COPRs, patches and script ownership | Maximum ownership |
| Reliability | Upstream integration coverage plus required Up validation | Smaller base, but custom kernel lifecycle remains Up's burden | Must establish desktop/boot integration from scratch |
| Update compatibility | Bazzite's repo priorities/versionlocks; manual Fedora gate | Greater freedom, greater dependency coordination | Highest dependency/testing burden |
| Security | More dependencies and upstream policies; explicit Up exclusions | Smaller attack surface and easier policy inventory | Entire policy/build trust chain must be maintained |
| Customization | GNOME survives; disable conflicting onboarding/defaults | Best match to existing defaults | Full control at substantial cost |
| Build costs | Large image; live RPM delta still needs repository availability | Smaller image, bespoke kernel and initramfs work | Largest engineering cost |
| Operational burden | Up canary and signature discipline still required | Up owns gaming regression coordination | No justified benefit for this personal system |

A does introduce meaningful costs: optional Bazzite software, broader upstream
trust, behavioral changes, and a large image. Removing conflicting onboarding and
retaining Up defaults is small enough to keep A preferable to maintaining copied
kernel/graphics patches. A future upstream incompatibility is grounds to revisit
this decision, not to accumulate an uncontrolled fork.

## Difference classification

Classes: **1 adopt**, **2 equivalent**, **3 optional/hardware-specific**,
**4 unnecessary for this PC**, **5 harmful/unsupported without evidence**.

| Area | Evidence / Bazzite implementation | Class and Up decision |
| --- | --- | --- |
| OGC kernel | `build_files/install-kernel-akmods`, matching akmods/extra artifacts and generic initramfs | 1 inherit lifecycle; 2 Up already selected OGC; no kernel speed claim |
| CPU responsiveness | scx packages available; `scx_loader.service` disabled in desktop build | 3 leave disabled; do not force scheduler or CPU affinity on 5800X |
| Foreground GPU memory booster | dmemcg-booster system/user services | 3 optional; Up masks both to avoid adding a privileged performance daemon without measurements |
| GameMode | Containerfile explicitly removes `gamemode` | 1 follow upstream; remove old `gamemoderun` options; do not assume additive benefit |
| Memory | zstd ZRAM `min(ram/2,16384)` MiB; hardware setup adjusts min_free_kbytes; high max_map_count | 1 inherit coherent defaults; 64 GB yields 16 GiB ZRAM, not 32 GiB; measure pressure before changing |
| I/O | udev uses kyber for SATA/NVMe SSD, bfq for rotational disks | 1 inherit upstream policy; no claimed superiority on the user's unidentified storage |
| Graphics | Terra Mesa selection/versionlocks; Terra XWayland/WirePlumber swaps; i686 libraries | 1 inherit as a unit; never mix another Mesa COPR or AMDGPU-PRO ICD into it |
| RADV / shaders | Mesa RADV; Steam launcher adds bounded shader background thread count if missing | 2 modern RADV already available; 1 integration; shader-thread behavior can increase background load, measure it |
| Wine / Proton | ntsync module load, FAudio/multilib, umu; Proton delivered separately | 1 inherit facilities; 3 actual sync path depends on Proton; no forced esync/fsync/ntsync flags |
| Gamescope | terra-gamescope and multilib libs; Deck session is a separate target | 1 compatible packages; 3 per-game nested compositor; 4 Deck session |
| MangoHud / vkBasalt | Terra MangoHud and vkBasalt in both architectures | 2 tooling already requested; keep overlays opt-in |
| Input | Steam devices, extest Wayland preload in wrapper, controller modules | 1 inherit; uinput access is part of controller support; test actual devices |
| Audio | PipeWire plus Terra WirePlumber, upstream audio policies | 1 inherit; 5 global forced tiny quantum/real-time priority without underrun measurements |
| Steam desktop | RPM + `bazzite-steam`, first-run handling, conditional multi-GPU workaround | 1 upstream integration; single-GPU 5800X/7900 XTX should not need hybrid-GPU workaround |
| GNOME / KDE | Separate Silverblue/Kinoite configuration and sessions | 2 retain GNOME; 4 KDE switch without evidence/user preference |
| VRR / HDR | Kernel, Mesa, compositor, game and display all participate | 3 verify actual GNOME session/support; KDE/Deck results are not promises for GNOME |
| Scaling / mixed displays | GNOME compositor and XWayland are relevant to Steam CEF presentation | 3 controlled display-matrix testing required |
| Flatpak | Upstream system manager applies global/app overrides | 5 incompatible with Up policy; mask; retain per-user apps and sandbox defaults |
| GNOME onboarding | Upstream first-user dconf and privileged setup | 5 overrides personal choices; mask; retain user's saved settings |
| Security | SELinux enforcing, signed kernel/UEFI enrollment, image signatures | 1 preserve; OCI trust and Secure Boot are separate; no disabling either |
| Updates | Desktop uupd timer; rpm-ostreed automatic timer disabled | 1 one orchestrator, verify follows Up's deployed origin; never run competing updaters |
| Extra software | Homebrew, Waydroid, assorted hardware/desktop utilities | 3 inherited footprint; not removed wholesale because dependency coupling needs evidence |
| Speculative tweaks | mitigations=off, blanket GPU perf flags, forced clocks, sandbox bypasses | 5 do not introduce |

## Upstream source and image ledger

- [Bazzite main](https://github.com/ublue-os/bazzite/tree/a8cf8aa19362e7012c40d6abeeeaf77c6c0aa99b), commit `a8cf8aa19362e7012c40d6abeeeaf77c6c0aa99b`, timestamp `2026-10-11T17:23:02-07:00`.
- **Pinned stable image source:** [Bazzite a945009](https://github.com/ublue-os/bazzite/tree/a9450099562e12e4ea0da19efcdefe6e284ffcdb). Commit timestamp `2026-10-06T10:52:55-07:00`. The published image's source differs from main; implementation decisions were checked against this revision too.
- Image `ghcr.io/ublue-os/bazzite-gnome:stable`, manifest `sha256:629fed5385623270d6356a33a483b5a69010be0f5b84a11b91f27b58558a32b6`, version `44.20261006.1`, created `2026-10-06T20:55:04Z`, reported kernel `7.2.8-ogc5.1.fc44.x86_64`. About 4.05 GB compressed layers. Metadata was read from GHCR, not inferred from main's kernel argument.
- [Universal Blue main](https://github.com/ublue-os/main/tree/e99142d0d579dcb256a2274f9fe26fb851819774), `e99142d0d579dcb256a2274f9fe26fb851819774`, `2026-10-11T04:09:17Z`: Containerfile, install/post-install/check scripts.
- [Image template](https://github.com/ublue-os/image-template/tree/1dd3b656c4eb99dea9fbf9bd8210a754bd94adab), `1dd3b656c4eb99dea9fbf9bd8210a754bd94adab`, `2026-09-04T23:32:58Z`: Containerfile and workflow. Its KDE base digest is not used for Up.
- [Fedora bootc/Atomic docs](https://forge.fedoraproject.org/atomic/docs/src/commit/f70770e66e00fd8fe83a14faf9f7924093c5d99a), `f70770e66e00fd8fe83a14faf9f7924093c5d99a`, `2026-10-01T15:52:57+02:00`. Fedora's rendered site blocked access; authoritative source was cloned instead.
- [Silverblue docs](https://github.com/fedora-silverblue/silverblue-docs/tree/45d3028df12db4bd4d19af7e3bd48deec3229a3e), `45d3028df12db4bd4d19af7e3bd48deec3229a3e`, `2026-01-09T01:18:09+01:00`: filesystem and deployment persistence.
- [bootc source/docs](https://github.com/bootc-dev/bootc/tree/ba0897da4650cbc05ad368cb90739ba7c3110ddd), `ba0897da4650cbc05ad368cb90739ba7c3110ddd`, `2026-10-09T16:14:52-04:00`: switch, rollback, image format and update semantics.

Key Bazzite files: `Containerfile`, `build_files/{install-kernel-akmods,build-initramfs,image-info,finalize}`, `system_files/desktop/shared/usr/bin/bazzite-steam`, `usr/libexec/bazzite-{hardware-setup,user-setup,flatpak-manager}`, `usr/lib/{sysctl.d,udev/rules.d,systemd}`, `etc/{systemd/zram-generator.conf,uupd/config.json}`, and `system_files/desktop/silverblue` schemas/dconf. Workflow variants were checked to distinguish desktop from Deck builds.

Additional living documentation accessed 2026-10-11 (publication date not supplied
unless stated): [Mesa RADV](https://docs.mesa3d.org/drivers/radv.html),
[Mesa environment variables](https://docs.mesa3d.org/envvars.html),
[Valve Proton README](https://github.com/ValveSoftware/Proton),
[Valve Gamescope README](https://github.com/ValveSoftware/gamescope),
[Wayland XWayland architecture](https://wayland.freedesktop.org/docs/book/Xwayland.html),
[Bazzite custom images](https://docs.bazzite.gg/Advanced/creating_custom_image/),
[Bazzite variant table](https://docs.bazzite.gg/General/FAQ/), and
[Steam resize report #10229](https://github.com/ValveSoftware/steam-for-linux/issues/10229)
(opened November 2023; historical symptom evidence only, not a diagnosis).

Cosign 3.1.3 verification found both keyless provenance and the legacy-format
public-key signature. The latter passed with `--new-bundle-format=false`, matching
Bazzite's pinned build workflow. Up explicitly uses that format for containers/image
attachment compatibility; no transparency-log or cryptographic checks are skipped.
This deprecated format needs review when upgrading Cosign or containers/image.
