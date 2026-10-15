# Haze

A [Quickshell](https://quickshell.org) shell for [Niri](https://github.com/YaLTeR/niri): a frame around your screen,
a notch that expands when you hover it, and little docks that grow out of the border.

<!-- screenshots: put images in docs/screenshots and link them here -->

## Features

- **Notch:** collapsed it is just the clock. Hover it and it opens into the control center: Wi-Fi, Bluetooth,
  Focus and Inbox tiles, volume and brightness sliders, a now-playing card with a wavy progress bar, and shortcuts.
  Click the clock for a mini calendar.
- **Docks on the border:** workspaces (top-left), system tray (top-right), notification toasts (bottom-right),
  and a volume/brightness OSD (right edge).
- **Launcher:** apps with frequency ranking, plus `=` calculator (`=2^10`, `=sqrt(16)`; plain math works too),
  `:` emoji picker, and `>` command runner (Enter runs it in a terminal, Ctrl+Enter in the background).
- **Clipboard history**, **wallpaper picker** (colors from the wallpaper via matugen), **screenshots and
  recording**, and a **power menu**.
- **Notification server:** Haze is the notification daemon, with a notification panel in the notch.
- **Settings app:** a floating window with search and a live preview. Everything applies instantly.

## Requirements

- Niri 26.04 or newer
- Quickshell 0.3 or newer
- `grim`, `wl-clipboard`, `cliphist`, `wl-screenrec`, `wtype`, `matugen`, `brightnessctl`, `libnotify`,
  `xdg-utils`, and NetworkManager (`nmcli`). The Nix package brings all but NetworkManager along.
- Fonts: [Rubik](https://github.com/googlefonts/rubik) and, optionally,
  [Material Symbols](https://github.com/google/material-design-icons) (falls back to Nerd Font symbols)

## Install

### Nix (flake + home-manager)

```nix
# flake.nix
inputs.haze.url = "github:h4shcore/haze";
inputs.haze.inputs.nixpkgs.follows = "nixpkgs";
```

```nix
# home-manager
{ inputs, ... }:
{
  imports = [ inputs.haze.homeModules.default ];

  programs.haze.enable = true;
  # programs.haze.systemd.enable = true;   # run as a user service instead of spawn-at-startup
  # programs.haze.installFonts = false;    # if you manage fonts yourself
}
```

Or just try it: `nix run github:h4shcore/haze`.

### Manual

```sh
git clone https://github.com/h4shcore/haze
ln -s "$PWD/haze/shell" ~/.config/quickshell/haze
qs -c haze
```

## Niri setup

```kdl
spawn-at-startup "haze"          // or "qs" "-c" "haze" for a manual install

binds {
    Mod+Space { spawn "haze" "ipc" "call" "launcher" "toggle"; }
    Mod+Period { spawn "haze" "ipc" "call" "launcher" "emoji"; }
    Mod+V { spawn "haze" "ipc" "call" "clipboard" "toggle"; }
    Mod+Comma { spawn "haze" "ipc" "call" "settings" "toggle"; }
    Print { spawn "haze" "ipc" "call" "capture" "toggle"; }
}
```

For a manual install replace `haze` in the binds with `qs -c haze`.

## Colors (matugen)

Haze reads `~/.config/quickshell/colors.json` live and runs `matugen image <file>` when you pick a wallpaper.
An example template and config are in [`extra`](extra). Without it, Haze uses a built-in dark palette.

## Control it

`haze ipc call <target> <function>` (or `qs -c haze ipc call …`):

| target | functions |
| --- | --- |
| `launcher` | `toggle` `show` `hide` `calc` `emoji` `run` |
| `clipboard` | `toggle` `show` `hide` |
| `wallpaper` | `toggle` `show` `hide` |
| `power` | `toggle` `show` `hide` |
| `capture` | `toggle` `region` `window` `fullscreen` `record` `stop` |
| `settings` | `toggle` `show` `hide` |

## Files Haze writes

| file | what |
| --- | --- |
| `~/.config/quickshell/haze-settings.json` | your settings (only values that differ from the defaults) |
| `~/.config/quickshell/colors.json` | colors, written by matugen |
| `~/.local/state/quickshell-haze/` | launcher history, command history, last wallpaper |

## Development

```sh
nix develop        # Quickshell + all tools
qs -p shell        # run straight from the repo
```

Adding a setting takes three steps: add a default in `shell/common/Settings.qml`, use `Settings.cfg.yourKey`
where it matters, and add one line to `pages` in `shell/modules/SettingsWindow.qml`.

## License

MIT
