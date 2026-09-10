# Mullvad IP Toggle

A command-line script for Linux that automatically rotates the
location/IP of your [Mullvad VPN](https://mullvad.net/) connection, at
configurable intervals.

## Features

- Rotates between **European Union**, **United States** (by city), or
  **Brazil** servers — regions can be combined into the same pool.
- Configurable rotation interval: 25s, 35s, 45s, 60s, or 120s.
- Saves your last configuration and offers to reuse it.
- "Smart" reconnection: waits for the real VPN handshake instead of a
  fixed delay, minimizing connection downtime.
- Automatic retry if the handshake fails.
- Optional public IP check on every rotation (requires `curl`).
- Desktop notification on every location change (requires `notify-send`).
- Visible countdown timer until the next rotation.
- Full country/city names (instead of raw codes).
- Updates the terminal window title with the current location.
- Keyboard controls while running:
  - `q` — stops the program and restores the default Mullvad configuration
  - `a` — skips ahead to the next rotation immediately, without waiting
- Logs every rotation to a file (`~/mullvad_ip_toggle.log`).

## Requirements

- Linux (tested on Linux Mint / Ubuntu).
- [Mullvad VPN](https://mullvad.net/en/download) installed, with the
  `mullvad` CLI available in your `PATH`.
- `curl` (optional, for the public IP check).
- `notify-send` (optional, for desktop notifications — usually already
  installed on most desktop Linux distributions).

## Installation

Run this command in a terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main/install.sh | bash
```

This will:

1. Download the script to `~/.local/bin/mullvad-ip-toggle`.
2. Create an entry in your applications menu (and, if it exists, a
   shortcut on your Desktop folder).

If `~/.local/bin` isn't already in your `PATH`, the installer will warn
you and tell you exactly what to add to your `~/.bashrc`.

## Usage

Once installed, run in a terminal:

```bash
mullvad-ip-toggle
```

Or search for **"Mullvad IP Toggle"** in your applications menu, or
double-click the Desktop icon (if one was created).

The program will ask:

1. Which region(s) to rotate through (you can combine several, e.g. `1 3`).
2. The interval between rotations.

After that, it starts rotating automatically. While it's running:
- press `a` to skip ahead to the next location right away;
- press `q` to stop and restore the default Mullvad configuration.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/mikewalker86/mullvad-ip-toggle/main/uninstall.sh | bash
```

The configuration file (`~/.mullvad_ip_toggle.conf`) and the log
(`~/mullvad_ip_toggle.log`) are not removed automatically.

## Disclaimer

This project is not affiliated with, endorsed by, or associated with
Mullvad AB. "Mullvad" is a registered trademark of Mullvad VPN AB. This
script only automates calls to the official `mullvad` CLI, which must
be installed separately.

## Changelog

- **2026-09-10** — Added a Settings menu: hide public IP, clean screen
  mode, custom rotation time, and a log file on/off toggle.
- **2026-09-10** — Fixed `wait_for_reconnection()` waiting only about
  half of the configured `HANDSHAKE_TIMEOUT` before giving up on the
  handshake and retrying.

## License

MIT — see [LICENSE](LICENSE).
