# Haze

A [Quickshell](https://quickshell.org) shell for [Niri](https://github.com/YaLTeR/niri) and
[Hyprland](https://hypr.land): a frame around your screen,
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

- Niri 26.04 or newer, or a recent Hyprland (Haze picks the right one on its own)
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

## Hyprland setup

Hyprland 0.55 and newer is configured in Lua, in `~/.config/hypr/hyprland.lua`:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("haze")   -- or "qs -c haze" for a manual install
end)

hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("haze ipc call launcher toggle"))
hl.bind("SUPER + PERIOD", hl.dsp.exec_cmd("haze ipc call launcher emoji"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("haze ipc call clipboard toggle"))
hl.bind("SUPER + COMMA", hl.dsp.exec_cmd("haze ipc call settings toggle"))
hl.bind("Print", hl.dsp.exec_cmd("haze ipc call capture toggle"))
```

<details>
<summary>Still on the old <code>hyprland.conf</code>?</summary>

```ini
exec-once = haze

bind = SUPER, SPACE, exec, haze ipc call launcher toggle
bind = SUPER, PERIOD, exec, haze ipc call launcher emoji
bind = SUPER, V, exec, haze ipc call clipboard toggle
bind = SUPER, COMMA, exec, haze ipc call settings toggle
bind = , Print, exec, haze ipc call capture toggle
```

</details>

Haze reserves its frame with layer-shell exclusive zones, so tiled windows stay inside it. Tune the gaps and
corner rounding to taste, for example `hl.config({ general = { gaps_out = 10 }, decoration = { rounding = 12 } })`.

- Haze detects Hyprland from `HYPRLAND_INSTANCE_SIGNATURE`. To force a compositor, set
  `HAZE_COMPOSITOR=hyprland` (or `niri`).
- Haze switches workspaces and logs out through `hyprctl dispatch`. It uses the Lua form
  (`hl.dsp.focus({ workspace = "3" })`) and falls back to the old one (`workspace 3`) when Hyprland
  doesn't accept it, so Lua configs, hyprlang configs and 0.55.x all work.
- The workspace dock shows Hyprland workspaces per monitor, labeled by workspace number. Click to switch,
  scroll to step through them. Special workspaces are not listed.
- Window screenshots read the windows on the focused monitor's active workspace through `hyprctl`.
- If you run Haze as a systemd user service, make sure it can see `HYPRLAND_INSTANCE_SIGNATURE`, for
  example by adding `hl.exec_cmd("dbus-update-activation-environment --systemd --all")` to the
  `hyprland.start` hook, or just start Haze from that hook.

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
