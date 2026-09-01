# Omarchy AirPlay Mirror

An Omarchy bar plugin for discovering AirPlay receivers and mirroring the
Wayland desktop through [DoubleTake](https://github.com/omarroth/doubletake).

## Features

- discovers Apple TVs and AirPlay-compatible TVs with mDNS/Avahi;
- remembers the selected receiver;
- starts and stops mirroring from the bar;
- supports pairing a new receiver with its four-digit PIN;
- exposes codec, encoder, FPS, latency, audio, and UDP port settings;
- provides `omarchy-airplay` IPC commands for keybindings and scripts.

## Languages

The plugin uses English by default and selects Norwegian Bokmål text for
`nb`, `nn`, and `no` system locales. Translations live in `i18n/I18n.js`; add
another language there by supplying the same message keys as the English map.

## Requirements

- Omarchy with the plugin-capable `omarchy-shell`
- `doubletake`
- `avahi` with its daemon running
- the relevant GStreamer encoder plugins for the chosen hardware backend

The receiver must be able to reach the local UDP port range configured for
the widget (default `60000-60010`). If a firewall is enabled, allow that UDP
range only from trusted receiver addresses.

## Install from a checkout

```bash
mkdir -p ~/.config/omarchy/plugins
ln -s "$PWD" ~/.config/omarchy/plugins/omarchy-airplay
omarchy-shell shell rescanPlugins
omarchy bar move omarchy-airplay --section right
```

The symlink makes edits in the checkout hot-reload during development.

## Use

Click the icon to open the receiver list. Each receiver has its own **Speil**,
**Velg/Fjern valg**, and **Glem** controls; the bar itself never starts a
mirror. **Glem** removes DoubleTake's saved pairing for that device, so the
next connection requires its PIN again.

For a new receiver, select it and start once so its PIN appears. The PIN field
is only shown when the selected receiver is not paired. Enter the PIN and choose
**Pair & connect**. DoubleTake stores credentials per receiver in its own
credential store.

Useful IPC calls:

```bash
omarchy-shell omarchy-airplay status
omarchy-shell omarchy-airplay toggle
omarchy-shell omarchy-airplay discover
omarchy-shell omarchy-airplay select "Living Room" 192.168.1.50 AA:BB:CC:DD:EE:FF
omarchy-shell omarchy-airplay unselect
```

## Known hardware notes

`h264` is the compatibility default. On recent Intel graphics, `vaapi` with
`vaapiDriver` set to `iHD` is often a good low-latency choice. Hybrid systems
may select an encoder that the compositor cannot feed correctly when `auto` is
used; explicitly choose the working backend in the Omarchy widget settings.

## License

MIT
