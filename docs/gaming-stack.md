# Gaming stack and hardware policy

Up targets a regular GNOME Wayland desktop on AMD/Intel graphics. The primary
Ryzen 7 5800X and RX 7900 XTX need the AMD kernel driver, modern Mesa RADV, and a
working compositor/display path. They do not require a Deck session, NVIDIA
image, proprietary AMD Vulkan stack, forced clocks, or extra Mesa repositories.

Bazzite maintains the kernel, matching modules, Mesa i686/x86_64, Vulkan loaders,
XWayland, PipeWire/WirePlumber, controller support and Steam launcher. The build
checks these packages and boot artifacts. Exact package versions are captured in
`/usr/share/up/packages.txt`; upstream metadata is retained in
`/usr/share/up/base-image-info.json`. New digest updates require review and a
hardware canary. Fedora-major changes deliberately fail the build until reviewed.

Steam remains an RPM. Its client/runtime and selected Proton versions update
outside the OS image; record them separately for comparisons. Bottles and Heroic
remain per-user Flatpaks and have their own runtimes and permissions. Avoid two
Steam installations unless deliberately running the diagnostic comparison.
There is no automatic migration or deletion of an existing Flatpak Steam library.

Gamescope is available as an opt-in nested compositor for individual games. It
is not the login session. MangoHud provides measurement; vkBasalt remains opt-in.
Do not globally enable overlays or post-processing while diagnosing Steam CEF.
Bazzite removes GameMode; existing `gamemoderun` launch prefixes must be removed.
Proton synchronization facilities depend on the selected Proton version and
kernel support. Installing host Wine is not a substitute for Steam's runtime.

## Conservative defaults

Keep automatic GPU clocks and normal platform power management. Leave scx_loader
disabled as upstream does; Up also masks the optional privileged dmemcg booster
and its user companion pending measurements; do not pin game threads or change the CPU governor
without repeatable evidence. Inherit ZRAM, I/O and memory policy as one tested
upstream set. On 64 GB, the reviewed ZRAM formula caps at 16 GiB. More RAM does not
justify disabling swap/ZRAM, setting enormous shader caches, or copying unrelated
sysctl collections. Check pressure/stutter first.

Mesa chooses appropriate RADV behavior for the GPU. Do not add historical
`RADV_PERFTEST` recipes, `AMD_VULKAN_ICD`, global ICD paths or async shader flags.
Defaults and valid options change; [Mesa documents current variables](https://docs.mesa3d.org/envvars.html).
The Bazzite Steam wrapper can set a shader-background thread count, apply a
multi-GPU workaround, and preload extest for Wayland controller support. These
are part of the comparison, not guaranteed performance improvements. Preserve
shader caches during routine troubleshooting; cold and warm measurements are
separate workloads.

For multi-monitor validation record each resolution, refresh, scale, connector,
VRR and HDR setting manually. Start with one monitor at integer scale, then add
mixed refresh and fractional scaling. Test fullscreen and borderless separately.
GNOME, KDE and Gamescope have different display paths; never infer GNOME HDR or
VRR results from a Deck/KDE claim. Keep the user's preferred setup unless a
specific measured issue requires a reversible workaround.

No fixed low-latency PipeWire quantum, GPU overclock, mitigations-off argument,
SELinux relaxation or Steam sandbox-disabling flag is introduced. Optional
Bazzite utilities remain installed; disable/remove additional services only after
inventorying what they do and measuring a benefit. Secure Boot module loading,
controller hotplug, audio, suspend/resume and boot behavior require physical
hardware validation.
