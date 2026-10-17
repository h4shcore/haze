pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Compositor integration for Niri and Hyprland: focused output, workspaces, actions, logout.
// Both backends are normalized to the same workspace shape, so the rest of the shell never cares:
//   { id, idx, name, output, is_active, is_focused, active_window_id }
// Detection: Hyprland if HYPRLAND_INSTANCE_SIGNATURE is set, else Niri.
// Force one with HAZE_COMPOSITOR=niri or HAZE_COMPOSITOR=hyprland.
// On Hyprland `idx` is the workspace id (Hyprland numbers workspaces globally, not per monitor).
//
// Hyprland 0.55+ with a Lua config (hyprland.lua) reads `hyprctl dispatch <x>` as Lua, so the old
// `hyprctl dispatch workspace 3` fails there. Every dispatch below tries the Lua form first
// (`hl.dsp.focus({ workspace = "3" })`) and falls back to the legacy form if Hyprland doesn't answer
// "ok" (Hyprland 0.55.x and hyprlang configs), so both keep working.
Singleton {
    id: root

    readonly property string kind: {
        const forced = Quickshell.env("HAZE_COMPOSITOR");
        if (forced === "hyprland" || forced === "niri") return forced;
        return Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "hyprland" : "niri";
    }
    readonly property bool isHypr: kind === "hyprland"

    property string focusedOutput: ""
    property var workspaces: []     // [{ id, idx, name, output, is_active, is_focused, active_window_id }]

    // `hyprctl dispatch` with a Lua expression, then the legacy spelling if that wasn't accepted
    function hyprDispatchCmd(lua, legacy) {
        return ["sh", "-c", "o=$(hyprctl dispatch \"$1\" 2>&1); case \"$o\" in ok*) ;; *) hyprctl dispatch $2 ;; esac", "haze", lua, legacy];
    }

    readonly property var logoutCmd: isHypr
        ? hyprDispatchCmd("hl.dsp.exit()", "exit")
        : ["niri", "msg", "action", "quit", "--skip-confirmation"]

    // raw compositor action (Niri only; Hyprland has no equivalent single entry point)
    function action(args) {
        if (!isHypr) Quickshell.execDetached(["niri", "msg", "action"].concat(args));
    }

    // switch to a workspace from the dock: `nw` is a normalized workspace (or null for an empty slot)
    function focusWorkspace(nw, fallbackIdx) {
        const n = String(nw ? nw.idx : fallbackIdx);
        if (isHypr) Quickshell.execDetached(hyprDispatchCmd("hl.dsp.focus({ workspace = \"" + n + "\" })", "workspace " + n));
        else action(["focus-workspace", n]);
    }

    // scroll through this monitor's workspaces: -1 = up / previous, +1 = down / next
    function stepWorkspace(delta) {
        if (isHypr) {
            // step through the workspaces the dock shows (this monitor's, in order), no wrap-around
            const mine = workspaces.filter(w => w.output === focusedOutput).sort((a, b) => a.idx - b.idx);
            const at = mine.findIndex(w => w.is_active);
            const next = at < 0 ? null : mine[at + (delta < 0 ? -1 : 1)];
            if (next) focusWorkspace(next, next.idx);
        } else {
            action([delta < 0 ? "focus-workspace-up" : "focus-workspace-down"]);
        }
    }

    function refresh() {
        if (isHypr) {
            if (!hyprProc.running) hyprProc.running = true;
        } else {
            if (!wsProc.running) wsProc.running = true;
            if (!outProc.running) outProc.running = true;
        }
    }

    // ── Niri ──
    Process {
        id: wsProc
        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.workspaces = JSON.parse(text); } catch (err) {}
            }
        }
    }

    Process {
        id: outProc
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text);
                    root.focusedOutput = o ? o.name : "";
                } catch (err) {}
            }
        }
    }

    // any niri event -> refresh (debounced)
    Process {
        running: !root.isHypr
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => debounce.restart()
        }
    }

    // ── Hyprland ──
    Process {
        id: hyprProc
        command: ["sh", "-c", "hyprctl -j monitors; echo '@@@'; hyprctl -j workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split("@@@");
                    const mons = JSON.parse(parts[0]);
                    const wss = JSON.parse(parts[1]);
                    const byName = {};
                    mons.forEach(m => byName[m.name] = m);
                    const fm = mons.find(m => m.focused);
                    root.focusedOutput = fm ? fm.name : "";
                    root.workspaces = wss
                        .filter(w => w.id > 0)      // special workspaces have negative ids
                        .map(w => {
                            const m = byName[w.monitor];
                            const active = !!m && m.activeWorkspace.id === w.id;
                            return {
                                id: w.id,
                                idx: w.id,
                                name: w.name,
                                output: w.monitor,
                                is_active: active,
                                is_focused: active && !!m.focused,
                                active_window_id: w.windows > 0 ? w.lastwindow : null
                            };
                        });
                } catch (err) {}
            }
        }
    }

    // any Hyprland event -> refresh (debounced). Uses Quickshell's own event socket, no socat needed.
    // The target is only touched on Hyprland, so the Hyprland singleton never starts under Niri.
    Connections {
        target: root.isHypr ? Hyprland : null
        function onRawEvent(event) {
            debounce.restart();
        }
    }

    Timer {
        id: debounce
        interval: 50
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
