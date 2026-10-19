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
- **Notification server:** Haze is the notification daemon, with a notification panel in the notch: action buttons,
  inline reply (for apps that support it), per-app mute (the bell on a card, or Settings → Notifications) and a History
  tab that survives restarts.
- **Control center extras:** a night light tile in the bento grid. The Bluetooth tile shows the battery of a single
  connected device. Settings → Connectivity has full Wi-Fi (scan, join, hidden networks, IP details, live speed, auto-connect,
  forget), Ethernet (link state, IP details, live speed, auto-connect, DHCP or manual address), Bluetooth (pair, connect, trust, forget, discoverable) and VPN (NetworkManager / WireGuard / OpenVPN profiles,
  Tailscale with exit nodes, config import) pages.
- **Now playing widget:** a large size with synced lyrics (lrclib.net) and an audio spectrum (cava); the medium size
  shows the line being sung.
- **Quick timers:** `timer 10m`, `timer 1h30m tea`, `timer 90s` or `timer 1:30` in the launcher; Enter starts it, a
  notification fires when it ends, and `timer` alone lists running ones (Enter cancels). `ipc call launcher timer` opens it.
- **Launcher extras:** `/` file search, `?` web search, `@` window switcher, `!` system actions, and unit / currency
  conversion (`12 km to mi`, `100 usd to eur`). See [Launcher](#launcher).
- **Lock screen:** blurred wallpaper, big clock and a password pill. Locks when idle, before suspend and on
  `loginctl lock-session` (the power menu's Lock). See [Lock screen](#lock-screen).
- **Settings app:** a floating window with search and a live preview. Everything applies instantly.

## Requirements

- Niri 26.04 or newer, or a recent Hyprland (Haze picks the right one on its own)
- Quickshell 0.3 or newer
- `grim`, `wl-clipboard`, `cliphist`, `wl-screenrec`, `wtype`, `matugen`, `brightnessctl`, `libnotify`,
  `xdg-utils`, `dbus-monitor` (from `dbus`), `cava`, `curl`, `fd` (optional, else `find`), `gammastep` and
  NetworkManager (`nmcli`). The Nix package brings all but NetworkManager along. Optional: `hyprpicker` (color
  picker on Hyprland), `tailscale` (VPN toggle in Settings).
- A PAM service for the lock screen (`login` works on most distros, see [Lock screen](#lock-screen))
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

## Launcher

Type in the launcher, or open it straight into a mode with `haze ipc call launcher files | web | windows | system`.

| prefix | what | Enter | Ctrl+Enter |
| --- | --- | --- | --- |
| `=` | calculator (plain math works too) | copy | |
| `:` | emoji | copy | |
| `>` | shell command | run in a terminal | run in the background |
| `/` | files and folders under `~` (hidden ones skipped) | open | copy the path |
| `?` | web search, `?yt lofi`, `?gh quickshell`, `?nix ripgrep`, `?w penguin`, `?maps nagpur`; a bare domain opens it | open | |
| `@` | open windows, most recent first | focus | close |
| `!` | system actions: lock, suspend, log out, reboot, shut down, caffeine, focus mode, night light… | run | |

- Plain queries also convert: `12 km to mi`, `72 f in c`, `3 cups to ml`, `100 usd to eur`. Currency rates come from
  open.er-api.com and are cached for 12 hours.
- Typing a clear action name (`lock`, `reboot`, `dnd`) puts that action above the apps. Log out, reboot and shut down
  ask for a second Enter within 3 seconds.
- The default web engine is under Settings → Launcher.

## Now playing widget

Settings → Widgets → Now playing size: small (art), medium (adds the current lyric line) or large (cover, three lyric
lines, spectrum, progress, controls). Lyrics are fetched from lrclib.net by artist and title and only for the widgets
that are showing; the spectrum needs `cava` and runs only while something plays. Both can be switched off there.

## Lock screen

Haze locks the session with `ext-session-lock` (Niri and Hyprland both support it), shows your last wallpaper
blurred, and checks the password through PAM.

- Locks after 10 idle minutes (Caffeine pauses it), before suspend, on `loginctl lock-session`, and with
  `haze ipc call lock lock`. All of it is under Settings → Lock.
- Type your password and press Enter. Backspace deletes, Ctrl+Backspace or Esc clears.
- There is no IPC call to unlock; the password is the only way out.
- **PAM service:** Haze uses `/etc/pam.d/login` by default. On NixOS add this to your system config and set
  Settings → Lock → PAM service to `haze`:

  ```nix
  security.pam.services.haze = { };
  ```

- **If Haze crashes while locked,** the compositor keeps the screen locked. Switch to a TTY (Ctrl+Alt+F3),
  start Haze again for your session, run `haze ipc call lock lock`, then type your password.

```kdl
// niri: lock from a key
Mod+Alt+L { spawn "haze" "ipc" "call" "lock" "lock"; }
```

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
| `lock` | `lock` `locked` |

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
