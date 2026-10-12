# Steam UI diagnosis

**2026-10-12 evidence update:** machine-specific package and service observations
remain in the local private audit. No CEF logs, launch options, client version,
actual monitor settings or GPU acceleration results establish the cause here.
See the [final implementation report](minimalism-implementation.md) for public
image verification results. The original assessment below predates that report;
references to an Ubuntu coding environment are historical.

**Current assessment:** root cause undetermined. Repository evidence confirms
native RPM Steam, standard desktop launch entry and no Up-authored CEF/GPU flags.
There is no evidence here that Flatpak caused the reported glitches, nor that a
slow kernel caused them. The user is currently in a separate Ubuntu coding
environment; its graphics, process state and logs are irrelevant to the gaming PC.
No performance or Steam hardware tests have been claimed.

## Hypotheses and confidence

| Hypothesis | Evidence and confidence | Discriminating test |
| --- | --- | --- |
| CEF GPU rendering / presentation interaction | Medium plausibility from resize/artifact symptoms; low confidence as root cause | Repeatable resize test; inspect local CEF errors; reversible GPU-rendering setting A/B |
| XWayland / Mutter / scaling / mixed refresh | Medium plausibility on GNOME multi-monitor setup; actual settings unknown | Single monitor/integer scale, then change one display variable at a time |
| Mesa regression or incoherent graphics libraries | Possible; no installed versions or GPU fault logs supplied | Same Steam build/settings on old/new image, confirm RADV and hardware renderer |
| Local env / launch overrides / extensions | Possible; no repo overrides, user state unknown | Inventory allowlisted variables; compare fresh user profile and default launcher |
| Steam client version / beta / runtime | Possible; not controlled by OS pin | Record client channel/build and runtime; compare stable/beta only after baseline |
| Duplicate Flatpak/RPM installs | Possible on deployed host, not configured by Up | Check both Flatpak scopes and the launched desktop file |
| CPU scheduler/kernel too slow | Low support; no contention or frame-time evidence | CPU/memory pressure sampling during reproduction; compare game results separately |
| Faulty GPU/display hardware | Unknown; no evidence | Check private amdgpu reset logs, cables, suspend behavior if system-wide artifacts occur |

Valve's [historical resize issue #10229](https://github.com/ValveSoftware/steam-for-linux/issues/10229)
shows this symptom class exists. Different software/hardware and its age prevent
using it as proof of the same bug. [XWayland is itself a Wayland client](https://wayland.freedesktop.org/docs/book/Xwayland.html);
the desktop session type alone does not establish Steam's rendering backend.

## Collect on the gaming PC

Run from the normal GNOME terminal, as your user, without sudo:

```bash
umask 077
/usr/bin/up-steam-diagnostics --graphics > steam-diagnostics.json
```

Before migration, run `python3 /path/to/up/usr/bin/up-steam-diagnostics --graphics`
from the repository checkout. The script makes no configuration changes or
network requests. `--graphics` explicitly initializes Vulkan; omit it for a
passive inventory. It reports selected package versions, graphics PCI identity,
Steam install scopes, environment **names only**, and error counts from at most
the last 2 MB of specific Steam logs. It omits raw logs, account IDs, hostnames,
serial numbers, process arguments and environment values. Review even this limited
report before sharing it. An unavailable probe is not proof that a component is
absent. Logs may be missing if Steam uses a nonstandard data location; the tool
does not search your home directory.

Privately record Steam Settings → System/Interface client build/channel and GPU
rendering setting, Proton version per test game, GNOME extensions, monitor
resolutions/scales/refresh, VRR/HDR status and which monitor is primary. Use
`xprop WM_CLASS` and click Steam to check whether the tested window is XWayland;
it may fail for a native Wayland window. Check any user-local `steam.desktop` or
launch options. Review values of flagged environment variables privately; an
extest preload from Bazzite is expected, while an unknown injected library needs
investigation. Do not post full environment dumps.

Inspect `~/.local/share/Steam/logs/cef_log.txt`, `webhelper.txt` and
`console-linux.txt` if present. Look for GPU-process crashes, lost contexts and
repeated failures at the reproduction time. Privately examine
`journalctl -b -k` for amdgpu reset/timeout events and the user journal for Mutter
or XWayland errors. Raw logs can expose paths, account identifiers and activity;
share only reviewed excerpts. No logs were available during this implementation.

## Controlled comparison

1. Close games and exit Steam normally. Keep the client version, channel, library
   view, downloads, shader-processing state and display layout fixed. Measure
   launch-to-interactive-library time with a stopwatch/video, not the lifetime of
   the `steam` shell process. Repeat five times, labelling first/cold vs warm runs.
2. At the same starting size, drag each Steam window edge for 30 seconds; perform
   ten maximize/restore cycles and ten monitor-to-monitor moves. Record artifact
   count, freezes and longest freeze. Keep cursor motion/workload comparable.
3. Repeat with one display at 100% scale. Then add the second monitor, mixed
   refresh rates and fractional scaling separately. Restore the original setup
   after each experiment. Avoid changing VRR and HDR at the same time.
4. If CEF remains suspect, compare the supported Steam setting for GPU-accelerated
   web views on/off, restarting Steam between runs. Keep it enabled as the normal
   baseline. Software rendering may reduce artifacts but increase CPU use and
   reduce responsiveness; record both results and restore it after the test.
   Do not add undocumented command-line switches or disable the sandbox.
5. Test a temporary separate OS user/profile to distinguish persistent user
   state/extensions from image defaults. Do not erase Steam data, shader caches,
   prefixes or the current dconf database as a troubleshooting shortcut.
6. Compare the old and candidate Up deployments with the same Steam client and
   saved settings. A whole-image comparison changes several components; an
   improvement does not isolate kernel versus Mesa versus compositor.
7. Only if unresolved, run a deliberate Flatpak comparison. Record its runtime
   version and permissions; use separate app data, run one client at a time,
   and do not concurrently access a Proton prefix. Flatpak changes sandbox,
   graphics runtime, library paths and portals together. Native RPM avoids that
   extra runtime boundary but is less isolated. Choose based on reproduced
   behavior; Up does not switch installation methods automatically.

A UI-only fix with unchanged game frame times is still valuable. A faster game
benchmark does not demonstrate that Steam resizing is fixed. Report these as
separate outcomes and attach version/settings information to any upstream issue.
