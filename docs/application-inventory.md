# Current application inventory

The final user-approved selection is implemented. See the [implementation report](minimalism-implementation.md)
for every RPM decision, dependency exception, service state and before/after measurement.
This replaces the earlier proposal; it does not instruct removal of existing user apps.

## First-login Flatpak defaults

These apps are installed in user scope only when absent from both user and system
scope. All 20 IDs were checked against Flathub metadata on 2026-10-12. Existing
remotes, apps and application data are preserved. The explicit removal list is empty.

| Application | Flatpak ID |
| --- | --- |
| Zen Browser | `app.zen_browser.zen` |
| Discord | `com.discordapp.Discord` |
| Flatseal | `com.github.tchx84.Flatseal` |
| Heroic Games Launcher | `com.heroicgameslauncher.hgl` |
| Bottles | `com.usebottles.bottles` |
| Celluloid | `io.github.celluloid_player.Celluloid` |
| Pods | `com.github.marhkb.Pods` |
| Fedora Media Writer | `org.fedoraproject.MediaWriter` |
| Calculator | `org.gnome.Calculator` |
| Calendar | `org.gnome.Calendar` |
| Extensions | `org.gnome.Extensions` |
| Loupe | `org.gnome.Loupe` |
| Sushi | `org.gnome.NautilusPreviewer` |
| Papers | `org.gnome.Papers` |
| Snapshot | `org.gnome.Snapshot` |
| Text Editor | `org.gnome.TextEditor` |
| Weather | `org.gnome.Weather` |
| Baobab | `org.gnome.baobab` |
| Clocks | `org.gnome.clocks` |
| Font Viewer | `org.gnome.font-viewer` |

## Available on demand

| Application | Flatpak ID / packaging |
| --- | --- |
| Visual Studio Code | `com.visualstudio.code` |
| Characters | `org.gnome.Characters` |
| Connections | `org.gnome.Connections` |
| Contacts | `org.gnome.Contacts` |
| Logs | `org.gnome.Logs` |
| Maps | `org.gnome.Maps` |
| Moonlight | `com.moonlight_stream.Moonlight`; removed from defaults only |
| Btrfs Assistant | RPM `btrfs-assistant`; no default installation |
| ROM Properties | RPM `rom-properties` and required integrations; no default installation |

Optional RPM host integrations require a deliberate image/layering decision, not
manual copying of executables. Ordinary Flatpaks remain available through GNOME
Software or the user's chosen remote. Availability does not mean automatic installation.

GNOME Terminal, GNOME Software, System Monitor, htop, Disks, papers-previewer,
Yelp, Malcontent Control, Orca, Tecla and Geoclue2 are retained as RPMs. Bazzite
Updater, Input Remapper and nvtop remain. Native Steam and Cardwire service remain;
Cardwire GUI is removed. Homebrew and MakeMKV remain as documented exceptions.

No changes in this selection reset Up's dconf preferences, fonts, Tela theme,
favorites or existing user settings. Image-level removal of Portal leaves any
old copied per-user autostart for the owner to review during migration.
