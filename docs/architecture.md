# Up architecture and audit

Review date: **2026-10-11 (America/Toronto)**. Repository baseline:
`2cb0443c51607e818b9e111b5c4aaea8713d4047`. This review concerns the repository,
not the Ubuntu coding environment. No gaming-PC logs or measurements were available
at that time. A later private machine audit superseded the initial readiness conclusions;
its inventory and host observations remain local.
The [final implementation](minimalism-implementation.md) records the approved
application decisions and fresh image checks.

## Decision

Use **architecture A**, the digest-pinned `ghcr.io/ublue-os/bazzite-gnome:stable`
AMD/Intel desktop image, with a small Up customization layer. It preserves GNOME
and RPM Steam without adopting the Deck session, KDE, NVIDIA stack, or a handheld
power-management profile. [Bazzite recommends image-template derivation](https://docs.bazzite.gg/Advanced/creating_custom_image/).
See [the comparison](bazzite-comparison.md) for costs and alternatives.

Bazzite owns kernel/modules, Mesa multilib, XWayland, Steam integration, controller
support, and gaming libraries. Up owns desktop preferences, personal applications,
virtualization packages, signing identity, and verification. Up does not copy
Bazzite's kernel installation scripts or maintain another graphics repository.

```text
Bazzite GNOME stable digest → personal RPMs → Up defaults and integration
                           → initramfs identity refresh → image verification
PR → static tests → upstream signature verification → build → smoke test
main/schedule → same checks → candidate push → sign and verify
manual promotion of tested digest → signature verification → moving tags
```

## Original functionality inventory

| Area | Baseline implementation | Preservation / change |
| --- | --- | --- |
| Base / release | Silverblue-main `44`, digest `1f05de28fc4ce8b004e524b1b5e1e0ce5f828b696c07a352bdb6d776b9242903` | Fedora 44 remains an explicit build gate; base becomes Bazzite GNOME stable |
| Kernel | Separate akmods `ogc-44`, digest `7bd0caa0cc0b710cb4b78b4115cb8d33e60d89a9b0463c5eadbdd7b91dc357ce`; custom RPM erasure, hook suppression, versionlock, dracut | Kernel and matching modules inherited together; custom installer removed |
| Desktop | GNOME, upstream session; dark mode, Tela-dark, flat mouse acceleration, favorites | Exact Up dconf file retained; Bazzite cosmetic schema overrides removed; existing user settings still win |
| Fonts / theme | Vendored Inter/JetBrains Mono; checksum-pinned Tela 2026-07-07 | Retained with licenses and hashes |
| Steam | `steam` RPM and `steam.desktop` favorite, no local wrapper or CEF flags | Native Steam retained; inherited `bazzite-steam` launcher supplies Wayland controller integration |
| Graphics | Explicit Mesa/Vulkan i686 additions; no custom ICD, RADV or acceleration environment variables | Inherit coordinated Bazzite graphics packages; verify 32/64-bit components |
| Gaming tools | Gamescope, GameMode, MangoHud, vkBasalt, FAudio, OpenXR, evtest, vulkan-tools | Inherit upstream variants; GameMode intentionally retired as upstream does; migration required for `gamemoderun` launch options |
| Virtualization | virt-manager, libvirt, qemu-kvm | Retained; no new host group or network mutation |
| Boot manager | rEFInd package | Mandatory; package retained, existing ESP integration must be preserved and hardware-tested |
| Exclusions | Firefox, classic-session/extensions, toolbox | Retained; removal now fails on unrequested dependency loss |
| Flatpaks | Eight per-user Flathub apps; empty removal list; hash-based login manager | Final selection now 20 apps; cross-scope deduplication and preserved change-trigger/retry semantics; existing remotes preserved |
| Services | dconf-update system oneshot; Flatpak user oneshot with retries | Retained; Bazzite global app manager and first-user setup masked to prevent conflicting policy |
| Controllers | hid_nintendo/hid_playstation preload | Retained; upstream controller integration inherited |
| User paths | `$HOME`, `$XDG_DATA_HOME`, state under `.local/share/ublue` | No hardcoded user; existing state persists; no home migration runs at build time |
| Automation | No repository Justfile; upstream ujust inherited | Bazzite ujust inherited; image-switch/reset recipes are administrative tools, not Up's migration path |
| Updates / CI | Daily builds; PR builds; base digest automerge; OGC manual review | Daily builds retained; all base changes manual review; one upstream uupd orchestrator |
| Supply chain | Pinned image/action refs and assets; Cosign signing **after moving tags** | Verify base signature; candidate signed and verified before `44` / `latest` promotion |
| Recovery | README bootc switch/rollback; no hardware/VM gate | Expanded migration, persistence, Secure Boot, signature-policy and manual canary guidance |

All tracked text files and workflows were inspected. Font binaries were treated as
assets, not reverse-engineered. There are no repository-authored Steam logs,
Proton installations, PipeWire tuning, custom boot arguments, CPU/GPU power
settings, benchmarks, or local Mesa patches. Inherited baseline package versions,
active updater state and deployed `/etc` overrides cannot be inferred from source
alone. The old base image was not booted during this review.

## Demonstrated weaknesses

The old design assumed ownership of a risky kernel replacement lifecycle without
owning Bazzite's matching userspace and driver integration. Its static kernel test
mostly searched for strings; that could not prove a successful boot. Separate
base/kernel digests could drift. OGC alone is not evidence of a Steam UI fix.
The 50-package limit did not count dependencies removed by DNF. Publication could
move release tags before signing failed. Base signatures were not verified in CI.
The Flatpak manager forcibly deleted an existing user remote. Documentation lacked
measured diagnostic procedures and distinguished few hardware-dependent checks.

## Integration and security boundaries

`packages.json` contains only Up additions/exclusions. A Fedora-major gate prevents
an unnoticed `stable` channel release jump. Gaming stack ownership stays upstream.
DNF may still resolve newer personal-package dependencies from live repositories:
a pinned base is **not** a bit-for-bit reproducible complete build. The final RPM
manifest and enabled repositories are recorded under `/usr/share/up/`. Offline
smoke tests compare the kernel binary hash and core gaming-package versions with
the pinned base and reject drift. Personal virtualization runtime directories
are declared in `usr/lib/tmpfiles.d/up-virtualization.conf`; transient DNF,
Flatpak-probe and root-home build state is removed before strict bootc lint.

`customize.sh` preserves Bazzite's base metadata separately, points image-info at
Up, identifies the desktop as Up, and regenerates the generic initramfs after
changing IMAGE_ID. ID/VARIANT_ID stay compatible with inherited tools. Up preserves
the existing signing key and adds a repository-scoped sigstore policy; it does not
relax other trust scopes. Host policy enforcement needs the migration steps.

Bazzite's Flatpak manager expands global/app permissions, and its user setup writes
dconf and invokes privileged NTP/Tailscale setup. Up masks both. Up removes the inherited
passwordless privileged-user-setup, CoreCtrl, Waydroid, and efibootmgr policy grants.
These were not existing Up functionality. The inherited split-lock mitigation
relaxation is masked, leaving the kernel default in place. Up adds no speculative CPU/GPU tweaks,
new privileged performance services, disabled SELinux, or sandbox bypasses.
Bazzite still has a broader trusted software/service surface than Silverblue,
including upstream hardware setup, controller services, uupd, and SELinux
workarounds. These are inherited compatibility components, not measured speedups.
Review their changes at every base update; see the comparison for tradeoffs.
The optional privileged dmemcg foreground booster and its user companion are
masked until measured benefit justifies enabling them; packages remain inherited.

`/usr` is image-owned. `/etc` uses deployment merge semantics; old admin overrides
may win over new defaults. `/var`, home directories, Flatpaks, Steam libraries,
prefixes and shader caches survive updates **and rollback**. An OS rollback is not
a user-data backup. See [Fedora Atomic filesystem documentation](https://github.com/fedora-silverblue/silverblue-docs/blob/45d3028df12db4bd4d19af7e3bd48deec3229a3e/modules/ROOT/pages/technical-information.adoc).
