# Minimalist Up implementation — 2026-10-12

**Repository implementation is complete; production deployment remains blocked on
boot and hardware validation.** The selected Bazzite GNOME architecture is retained.
All work was confined to repository files, temporary tools and isolated rootless
container storage. Nothing was published, rebased, rebooted or installed into a
host OS. No EFI entries, user applications or user data were changed.

## Scope and evidence

The base remains
`ghcr.io/ublue-os/bazzite-gnome:stable@sha256:629fed5385623270d6356a33a483b5a69010be0f5b84a11f27b58558a32b6`.
Its source revision is `a9450099562e12e4ea0da19efcdefe6e284ffcdb`.
The complete image was pulled, its Bazzite signature verified, and its RPM database,
files, dependency solver, units and script references inspected in containers.

A privately supplied gaming-PC inventory was inspected separately. The raw export,
package/service comparisons and machine-specific audit remain local and Git-ignored.
Development-host hardware and running services were not used as gaming evidence.
The developer environment is a Flatpak SDK; host Podman was accessible through
`flatpak-spawn --host`. It used dedicated `.up-build/storage` and `.up-build/run`
directories, without changing host packages or services.

The comparison below uses a new build of the staged repository immediately before
this implementation, then the final implementation, against the same pinned base.
This avoids confusing old Silverblue Up, upstream Bazzite and composed Up.
[Reviewable evidence](audit/2026-10-12-minimalism/README.md) records inventories,
transactions, checks, identities and measurement details. Raw machine exports and
local build storage are excluded from Git and container build contexts.

## Implemented application decisions

The [Flatpak manifest](../etc/flatpak/user/install) now declares **20 applications**:
Zen, Discord, Flatseal, Heroic, Bottles, Celluloid, Pods, Fedora Media Writer,
Calculator, Calendar, Extensions, Loupe, Sushi, Papers, Snapshot, Text Editor,
Weather, Baobab, Clocks and Font Viewer. All 20 canonical IDs returned matching
Flathub metadata, including `org.gnome.NautilusPreviewer` for Sushi.
These are first-login user installations, not Flatpak payloads baked into OCI.

Moonlight is removed only from the default list. VS Code, Characters, Connections,
Contacts, Logs and Maps remain available on demand. The removal manifest is empty.
The manager checks both user and system app IDs, installs only missing defaults,
preserves remote URLs/preferences and does not update or migrate existing apps.
It does not remove existing duplicates, Moonlight, user apps or app data. Its
configuration hash, no-op behavior and retry-on-failure remain. An unchanged
configuration respects subsequent user uninstall choices. Disabled/custom Flathub
remotes are preserved; installation failure remains retryable rather than silently
rewriting remote policy.

GNOME System Monitor and htop are added. GNOME Terminal remains the preferred
terminal through `/etc/xdg/xdg-terminals.list`, with its existing favorite intact.
GNOME Software is the retained graphical app store; Bazaar is removed.

Exactly **33 optional RPMs** were removed without transitive erasures:

| Decision | Packages / applications |
| --- | --- |
| Remove selected Bazzite frontends | Lutris, Waydroid and its SELinux subpackage, Bazaar, Webapp Manager, Bazzite Portal, Cardwire GUI, btop, yad, msedit, GSConnect and its Nautilus integration |
| Available on demand | Btrfs Assistant; ROM Properties and its common, GTK4, LocalSearch and utility subpackages |
| Remove redundant GNOME UI/cosmetics | Ptyxis, GNOME Search Yafti, GNOME Rounded Blur, Steam Deck backgrounds and GNOME presets |
| Remove optional administration/network UI | Cockpit bridge/system/SELinux/networkmanager/storaged/podman/files, Tailscale, Firewall Config, Rygel |

The original ten Firefox/classic-session/extension/toolbox exclusions are retained.
No speculative exclusions were added for absent components. The full package
names are in [packages.json](../packages.json). No executable was manually deleted
to bypass RPM ownership. Two unowned desktop declarations were removed separately:
Portal's skeleton autostart and the Waydroid restart launcher. Existing users'
home autostarts remain untouched and need review during migration.

`yad` references found in the inherited Portal configuration belong to the removed
Portal workflow; retained updater and runtime helper searches found no required
invocation. Portal's executable is owned by its removed RPM. Hardware setup,
account/session creation, Up's app installer and Bazzite Updater remain independent.
Some inherited documentation/ujust recipes still describe optional applications;
those recipes do not imply that the applications remain installed.

## Preserved, absent and retained exceptions

| Area | Final decision and evidence |
| --- | --- |
| Boot and platform | rEFInd, Bazzite kernel/modules, firmware, shim/GRUB tooling and boot integration retained. Kernel binary and protected RPM versions compared against the base. |
| GNOME foundation | Shell, GDM, Settings, Nautilus, Wayland/XWayland, portals, Bluetooth, Color Manager, GCR, accounts, Evolution backend, accessibility and localization retained. |
| Requested GNOME tools | Terminal, Software, System Monitor, htop, Disks, papers-previewer, Yelp, Malcontent Control, Orca, Tecla and Geoclue2 checked in the composed image. |
| Security/audio | SELinux configuration, Polkit, firewalld, PipeWire and WirePlumber preserved. Removing Firewall Config removes only the optional GUI. Rygel media sharing is optional and had no required dependent erasures. |
| Gaming | Native Steam, steam-devices, Cardwire daemon, Gamescope, MangoHud, vkBasalt, OpenXR, extest, Vulkan tools, Mesa/RADV/OpenGL and i686 support retained. No speculative launch, GPU or scheduler flags. |
| umu / GameMode | umu-launcher and wrapper retained as upstream gaming compatibility. GameMode is absent in the selected base and remains absent. Old PC launch options were not exported; review any `gamemoderun` prefixes before game tests. |
| Development | virt-manager, libvirt, QEMU/KVM, Podman and Distrobox retained; no narrowing of the requested libvirt feature set or host group changes. |
| Hardware utilities | ryzenadj, fw-fanctrl, framework-system, fw-ectool, DisplayLink and CEC retained, including the explicitly requested Framework tools on the AMD desktop. |
| Personal settings | Inter, JetBrains Mono, Tela, Up's dconf profile, dark theme, mouse settings and favorites retained. Saved user preferences continue to override defaults. |
| GNOME Browser Connector | Retained: 128,921-byte RPM, no required dependents, optional browser/extension integration without a dedicated always-running system service. No claim that Extensions Flatpak requires it. |
| International IBus engines | Retained: Anthy, Chewing, Hangul, libpinyin, m17n, Mozc, Unikey and Typing Booster. Installed engines are not all active input methods; removing them would narrow supported input/localization without an established requirement. |
| LocalSearch | Retained: Nautilus declares the dependency. Keep search/index integration; measure indexing on the real user data later. |
| MakeMKV — blocked removal | RPM dependency queries alone show no consumer, but both `libaacs.so.0` and `libbdplus.so.0` resolve to its `libmmbd.so.0`. Preserve the codec arrangement; do not replace these links manually. |
| ModemManager — blocked removal | Offline solver would also erase NetworkManager-bluetooth and NetworkManager-wwan. Preserve Bluetooth/network support. |
| iSCSI — blocked removal | Final-image solver would erase libvirt and its storage drivers along with iscsi-initiator-utils. Preserve the explicitly requested libvirt feature set. |
| Already absent | GNOME Tour, GNOME Initial Setup, AppIndicator, InputPlumber, PowerStation, Deck gaming session and proprietary NVIDIA driver stack. No new exclusions or reinstalls. NVIDIA firmware is not a proprietary driver installation. |

### Homebrew assessment

Homebrew is retained as a maintainability exception, not a hard dependency of the
OS updater. The base supplies a non-RPM `/usr/share/homebrew.tar.zst` payload,
conditional first-boot extraction service, shell/fish environment integration,
Bold Brew launcher, ujust recipes and a 21-tool Bazzite CLI Brewfile. The latter
includes `gh`, `rg`, `fd`, `yq`, ShellCheck, Starship, Atuin, Zoxide and other tools.
A Brewfile declaration is not proof every tool is installed in a given user's
persistent Homebrew tree. `brew-setup` also assumes UID/GID 1000 for the shared
prefix; review ownership on the actual PC before first deployment.

uupd's resolved configuration enables its Brew module and supports disabling that
module independently. Its separate Brew update/upgrade timers are disabled, so
uupd remains the updater. Removing Homebrew cleanly would require maintaining a
coordinated exception to payload, setup, shell, launcher and recipe integration,
plus deliberately choosing replacements for optional CLI tools. That cost is not
justified for this small derivative. No Homebrew directory or executable was
manually deleted. The inherited compressed Homebrew layer remains 155,591,669 bytes;
whiteouts would not remove it from downloads anyway.

## Services, activation and background work

These are **image unit-file states**, not evidence of running processes. Static
units, sockets, D-Bus, udev, autostart, existing `/etc` and user overrides can start
services that are not enabled. No container PID list is presented as a desktop
resource measurement.

| Component | Image state / action |
| --- | --- |
| Bazzite Updater / uupd | RPM retained; uupd.timer enabled; OS, Flatpak and Brew modules enabled, Distrobox updating disabled upstream. No updater was executed. |
| Competing update schedules | rpm-ostreed-automatic, bootc-fetch-apply-updates, Brew update/upgrade and Podman auto-update timers disabled. Check surviving old host Flatpak timers before deployment. |
| Input Remapper / Cardwire | Services enabled and retained; Cardwire GUI removed. |
| fw-fanctrl | Service and suspend companion disabled; tools remain available. No Framework fan daemon enabled for this desktop. |
| DisplayLink / CEC | DisplayLink unconditional enable link removed; retained USB udev SYSTEMD_WANTS rule can activate it for DisplayLink hardware. CEC service/timer remain disabled. |
| scx / dmemcg | scx-scheds installed; scx_loader disabled. dmemcg-booster installed; system and user booster services masked. No tuning enabled or performance benefit claimed. |
| Uresourced | One inherited `uresourced-dmemcg` implementation. System service disabled but D-Bus activation possible; user service static and session-linked. Not a second independently installed Uresourced stack. Runtime interaction remains a hardware test. |
| Cockpit / Waydroid | Cockpit RPMs removed; inherited container-launching cockpit.service masked. cockpit.socket already absent. Waydroid package/service removed. |
| VirtualBox guest | Package retained; system service and resize client conditioned on Oracle virtualization. VBoxClient-all checks `/dev/vboxguest` before launching its clients. |
| VMware / QEMU guest | Retained upstream hypervisor/device-gated integration; VMware service requires VMware virtualization; QEMU agent is bound to its virtio guest-agent device. No claim they run on the physical AMD desktop. |
| Libvirt | Modular daemons and sockets retain upstream/package defaults; monolithic libvirtd remains disabled. QEMU daemon supports idle timeout. User access/VM networking still require session validation. |
| iSCSI | iscsi.service stays upstream-masked; iscsid/iscsiuio services disabled, sockets enabled. Onboot/starter units are enabled but conditioned on sessions/configured nodes. Keeping socket activation preserves libvirt storage capability. |
| SSSD | Retained authentication/KCM stack. Main service enabled with configuration-file/directory conditions; KCM socket enabled. Do not prune authentication based on process-name assumptions. |
| Evolution / LocalSearch | Retained session integrations. Actual indexing, calendar/account activity and CPU/RAM use unmeasured. |
| GNOME autostart | Portal skeleton entry removed; Steam autostart remains excluded by the earlier migration. Existing users' copied entries are not deleted. |

## Dependency safety and validation

The build now asks DNF5 to **store** an offline, no-autoremove removal transaction,
checks every action and full NAME.ARCH against the requested set and 50-package
ceiling, then replays exactly that plan. Unsupported/malformed plans or dependent
erasures fail before mutation. The final installed NAME.ARCH comparison remains a
second guard, including loss of only i686. This is image composition, not a host
transaction or a recovery mechanism.

The real solver accepted all 33 selected erasures with no additional removals.
Separate stored plans demonstrate why ModemManager and iSCSI were retained.
The complete build also runs `dnf5 check`, package/interface checks, kernel and
initramfs inspection, and `bootc container lint --fatal-warnings`.

| Verification category | Result |
| --- | --- |
| Static analysis | PASS: Bash, jq/JSON, ShellCheck, shfmt, behavior tests for transaction guards and Flatpak scope/retries, six policy tests, four diagnostic tests, Polkit mock tests, actionlint and diff hygiene. |
| Container image verification | PASS: full before/after builds; strict bootc lint; offline smoke; OCI labels; preserved package versions and kernel hash; removal results; required packages; service declarations; preferred terminal and boot artifacts. |
| Signature validation | PASS for the pinned Bazzite base with its key. Previous audit also rejected the wrong Up key. Local Up builds are unsigned; release signing/promotion workflows were not executed. |
| Flatpak catalog | PASS: all 20 default IDs match Flathub metadata. Full downloads and graphical launches not tested. |
| VM verification | NOT TESTED. QEMU exists, but usable KVM access and a prepared installed bootc/rEFInd VM disk were unavailable. Container lint is not a VM boot test. |
| Physical hardware verification | NOT TESTED: boot, Secure Boot, rEFInd, GNOME login, Steam UI, games, multimonitor, suspend, devices, updater and rollback. |

Inherited GNOME schema deprecation/missing optional screensaver-key warnings and
dracut's container syslog notice occurred during successful builds. Strict lint
reported 14 passed checks and one skipped check.
No claim is made about runtime SELinux enforcement from reading an image config,
or real Polkit prompts from the mocked authorization test.

## Before/after measurements

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

The [evidence notes](audit/2026-10-12-minimalism/README.md) define the collection method and image identities.
RPM inventory excludes public signing-key pseudo-packages when comparing package
counts. The -30 comparison above is against pre-cleanup Bazzite-based Up,
not a claim that it is smaller than a deployed Silverblue-based OS.
Desktop-entry counts filter Hidden/NoDisplay and GNOME visibility; they
are launchers, not a count of independent binaries. Flatpak defaults increase from
8 to 20 because the selected GNOME tools are now explicit. Already installed apps
in either scope satisfy those defaults, so 20 is an upper bound on fresh app
installs, not a promise to download 20 on every login.

Measured installed RPM payload and merged `/usr`/`etc`/`opt` allocation decrease.
**Compressed OCI size does not decrease:** the derived image retains all inherited
layers and adds its own changes. Local OCI exports measure compressed layer bytes
separately from merged filesystem allocation. This is not a flattened image or a
claim about deployment disk allocation, per-user Flatpak runtimes, download caching,
RAM, CPU, FPS or battery usage. Those runtime measurements are not available.

## Boot, security, deployment and recovery

The existing mandatory rEFInd strategy is preserved. Package availability, a
matching OGC kernel and an intact generic initramfs do not verify the actual ESP,
rEFInd scanning/chainloading configuration, firmware trust or greenboot recovery.
Bazzite's first-boot hardware setup is unchanged: it can append
`bluetooth.disable_ertm=1`, remove `nomodeset`, stage rpm-ostree kernel arguments
and reboot before user sessions. Rehearse this sequence and its interaction with
the existing boot path before relying on the candidate.

OCI signatures and kernel Secure Boot trust are separate. Confirm the candidate
certificate through the still-trusted old deployment and preserve the working
EFI chain. See the [upstream Secure Boot guide](https://docs.bazzite.gg/General/Installation_Guide/secure_boot/)
and the stricter owner-run [migration and rollback procedure](migration.md).
No key enrollment or bootloader command was run here.

The earlier audit's security fixes remain: scoped Up image policy, verified-base
CI, signed candidate-only publication, manual exact-digest promotion, authentication
for five privileged helper actions, removal of broad inherited Polkit grants and
a mask for the inherited split-lock mitigation relaxation. SELinux and firewalld
are preserved. Live Polkit, signature-enforced updates and actual firewall behavior
must still be tested after boot.

For a future authorized migration: re-read real bootc/rpm-ostree state, review any
pending deployment deliberately, back up ESP/rEFInd, `/etc`, home and VM/
game data, pin the actual known-good deployment, record updater state, and verify
the exact signed **Up candidate**. Rehearse in a disposable VM, then stage that
digest in a controlled physical canary. Coordinate automatic updates and inspect
both staged and rollback entries before reboot. Follow the linked procedure rather
than substituting the Bazzite base digest or a moving tag.

Recovery must work through rEFInd before release: select the pinned known-good
entry if the candidate fails to boot; for a usable candidate, inspect and stage
`bootc rollback`, then reboot separately. Home and `/var` are shared across OS
rollback and require their own backups. Do not rebuild/reinstall the bootloader
as an automatic recovery step.

Required physical tests include Secure Boot and first-boot kargs/reboot behavior,
GNOME/portals/audio, native Steam CEF rendering, RADV 32/64-bit game launches,
controllers, mixed-resolution/high-refresh monitors, suspend/resume, optional
DisplayLink/CEC, Flatpak scope behavior, virt-manager access/network/storage,
Uresourced/dmemcg state, uupd against Up's origin, signature rejection and recovery.
Measure idle services/RAM/CPU and frame times under comparable workloads before
claiming any performance improvement.

**Verdict:** the approved minimalism implementation is built and container-verified.
It is ready for the documented VM/physical canary process, not production promotion.
Unresolved rEFInd/Secure Boot/update/rollback validation remains a deployment blocker.
