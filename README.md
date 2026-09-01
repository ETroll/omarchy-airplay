# Omarchy AirPlay Mirror

An Omarchy bar plugin for discovering AirPlay receivers and mirroring a Wayland
desktop through [DoubleTake](https://github.com/omarroth/doubletake).

It is designed for Apple TV and compatible AirPlay receivers on the local
network. The plugin discovers receivers, keeps a chosen receiver handy, and
lets you pair, start, stop, or forget a receiver from the Omarchy bar.

![AirPlay Mirror receiver list](preview.png)

## Features

- Discovers AirPlay receivers through mDNS/Avahi.
- Starts and stops desktop mirroring from the bar.
- Pairs new receivers with the PIN displayed by the receiver.
- Lets you select, unselect, and forget individual receivers.
- Shows the Wayland screen/window/region picker for every new session by
  default.
- Supports configurable codec, encoder, FPS, latency, audio, and UDP port
  range settings.
- Includes English text and Norwegian Bokmål/Nynorsk locale support.
- Exposes `io.github.etroll.omarchy-airplay` IPC commands for keybindings and scripts.

## Requirements

This is an Omarchy/Arch Linux plugin. It needs:

- Omarchy with a plugin-capable `omarchy-shell`.
- A working Wayland capture portal. Omarchy normally provides PipeWire and
  `xdg-desktop-portal-hyprland`.
- [DoubleTake](https://github.com/omarroth/doubletake), the AirPlay sender.
- Avahi for receiver discovery, including the `avahi-daemon` service.
- `jq`, used only to inspect and safely remove an individual saved pairing.
- GStreamer runtime plugins required by DoubleTake.
- Optional firewall assistance: `ufw` and Polkit's `pkexec`.

Install the required repository packages:

```sh
sudo pacman -S --needed \
  avahi jq \
  gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad \
  gst-plugins-ugly gst-libav \
  pipewire xdg-desktop-portal xdg-desktop-portal-hyprland
```

Install the stable DoubleTake package from the AUR with your AUR helper:

```sh
yay -S --needed doubletake
```

`doubletake-git` is an alternative for users who specifically need the newest
upstream changes. Do not install it together with `doubletake`.

Enable receiver discovery:

```sh
sudo systemctl enable --now avahi-daemon
```

Verify the essentials before installing the plugin:

```sh
command -v doubletake
command -v avahi-browse
systemctl is-active avahi-daemon
```

### Firewall

No manual firewall rule is normally required. DoubleTake uses at least three
local UDP ports for each active receiver; the plugin defaults to
`60000-60010`.

When UFW blocks incoming media traffic, select the receiver and choose
**Allow selected receiver** in the widget. The plugin detects the active
Wi-Fi/Ethernet network and opens the configured UDP range only for that
receiver's current IPv4 address. Polkit shows the system administrator prompt
before anything changes.

The plugin records only rules it created and removes that rule when you choose
**Forget** for the receiver. This is optional and requires `ufw` and `pkexec`
(Polkit). If UFW or Polkit is unavailable, configure the firewall according to
your system's documentation instead; do not open the range to untrusted
networks.

## Install

### From GitHub

After this repository has been published, install the plugin with Omarchy:

```sh
omarchy plugin add https://github.com/ETroll/omarchy-airplay.git --enable
omarchy bar move io.github.etroll.omarchy-airplay --section right
```

The first command installs a user-owned copy below
`~/.config/omarchy/plugins/`; it does not modify Omarchy's packaged files.

### From the Omarchy Plugin Marketplace

Once the listing has been approved, install it from the Omarchy plugin browser
or with the marketplace-provided install command. The marketplace listing
points to the same public GitHub repository; it does not host a separate copy
of the plugin.

### Development checkout

For local development, clone the repository and link it into your user plugin
directory:

```sh
git clone https://github.com/ETroll/omarchy-airplay.git
cd omarchy-airplay
ln -s "$PWD" ~/.config/omarchy/plugins/io.github.etroll.omarchy-airplay
omarchy-shell shell rescanPlugins
omarchy bar move io.github.etroll.omarchy-airplay --section right
```

Saved changes under `~/.config/omarchy/plugins/` normally reload
automatically. If the plugin does not appear after a manifest change, run
`omarchy-shell shell rescanPlugins`.

## Use

Click the AirPlay icon in the bar to open or close the receiver list. Click a
receiver row to select it; click that row again to clear the selection. Use the
screen icon on the right to start or stop mirroring.

For a new receiver, select it and press the screen icon once. Enter the PIN
shown by the receiver, then choose **Pair & connect**. DoubleTake stores the
receiver credential in `~/.config/doubletake/credentials.json` for later use.
The PIN field is only shown after a connection has been attempted.

The trash icon is shown only for paired receivers. It removes that receiver's
saved DoubleTake credential, so the next connection must pair again. It does
not change the receiver itself.

By default, **Choose capture source every time** is enabled. A new mirroring
session opens the portal picker so you can choose a screen, window, or region.
It clears only the saved capture selection for that receiver and keeps its
AirPlay pairing intact.

## Configure

Open the widget's settings in Omarchy to configure the DoubleTake executable,
video codec, hardware encoder, FPS, target latency, audio, and UDP port range.

`h264` is the compatibility default. On current Intel graphics, `vaapi` with
the VAAPI driver set to `iHD` is often a good low-latency option. On hybrid-GPU
systems, explicitly selecting the working encoder can be more reliable than
`auto`.

Useful IPC calls:

```sh
omarchy-shell io.github.etroll.omarchy-airplay status
omarchy-shell io.github.etroll.omarchy-airplay toggle
omarchy-shell io.github.etroll.omarchy-airplay discover
omarchy-shell io.github.etroll.omarchy-airplay select "Living Room" 192.168.1.50 AA:BB:CC:DD:EE:FF
omarchy-shell io.github.etroll.omarchy-airplay unselect
```

## Troubleshooting

### No receivers are listed

Confirm Avahi is running, then test discovery:

```sh
systemctl is-active avahi-daemon
avahi-browse --resolve --terminate _airplay._tcp
```

The computer and receiver must be on the same network, and multicast DNS must
not be blocked by the network.

### The portal picker does not appear or mirroring is black

Check that PipeWire and the Hyprland portal are running, then stop the mirror
and start it again from the receiver row. Selecting a source in the portal is
required before video can begin.

### Mirroring connects but does not update

Try `h264` at 30 FPS, then explicitly select the encoder that matches your GPU
(`vaapi`, `nvenc`, or software). If UFW is enabled, use **Allow selected
receiver** for the selected receiver and retry.

### Inspect plugin validation and logs

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.etroll.omarchy-airplay
omarchy plugin list --json | jq '.[] | select(.id == "io.github.etroll.omarchy-airplay")'
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

## Remove

Stop any active mirror, then remove the plugin by its manifest ID:

```sh
omarchy plugin remove io.github.etroll.omarchy-airplay
```

This removes only the installed plugin copy. It does not uninstall DoubleTake,
remove Avahi, or delete saved receiver credentials. If you also want to remove
all DoubleTake pairings, delete `~/.config/doubletake/credentials.json`
yourself after checking that it contains no credentials you want to keep.

## Security and privacy

Plugins run with the user's permissions. Review this repository and its
dependencies before installing it. Screen contents are sent to the selected
AirPlay receiver on the local network. Pair only with receivers you trust, and
keep firewall rules limited to trusted receiver addresses.

## Languages

The plugin uses English by default and selects Norwegian Bokmål text for `nb`,
`nn`, and `no` system locales. Translations live in `i18n/I18n.js`; add another
language there by supplying the same message keys as the English map.

## License

[MIT](LICENSE)
