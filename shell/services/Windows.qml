pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Open windows for the launcher's "@" mode, on Niri and Hyprland:
//   { id, title, appId, ws, focused, stamp }   (stamp: higher = used more recently)
// Rows come back most-recent first with the focused window last, so "@" then Enter flips to the previous one.
Singleton {
    id: root

    property var list: []

    function refresh() {
        if (Compositor.isHypr) { if (!hyprProc.running) hyprProc.running = true; }
        else if (!niriProc.running) niriProc.running = true;
    }

    function focus(w) {
        if (Compositor.isHypr)
            Quickshell.execDetached(Compositor.hyprDispatchCmd("hl.dsp.focus({ window = \"address:" + w.id + "\" })", "focuswindow address:" + w.id));
        else
            Compositor.action(["focus-window", "--id", String(w.id)]);
    }

    function close(w) {
        if (Compositor.isHypr)
            Quickshell.execDetached(Compositor.hyprDispatchCmd("hl.dsp.window.close({ window = \"address:" + w.id + "\" })", "closewindow address:" + w.id));
        else
            Compositor.action(["close-window", "--id", String(w.id)]);
        list = list.filter(x => x.id !== w.id);
    }

    function rows(query) {
        const q = (query ?? "").trim().toLowerCase();
        const out = [];
        for (const w of list) {
            const hay = (w.title + " " + w.appId).toLowerCase();
            if (q !== "" && !hay.includes(q)) continue;
            let entry = null;
            try { entry = DesktopEntries.heuristicLookup(w.appId); } catch (err) {}
            const app = entry?.name ?? w.appId;
            out.push({
                id: "win:" + w.id,
                kind: "win",
                win: w,
                title: w.title !== "" ? w.title : (app || "Window"),
                subtitle: (app || "Window") + (w.ws !== "" ? "  ·  workspace " + w.ws : "") + "  ·  Ctrl+Enter closes",
                icon: entry?.icon ?? w.appId.toLowerCase(),
                stamp: w.stamp,
                focused: w.focused
            });
        }
        out.sort((a, b) => (a.focused - b.focused) || (b.stamp - a.stamp));
        return out.slice(0, 60);
    }

    // ── Niri ──
    Process {
        id: niriProc
        command: ["niri", "msg", "--json", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.list = JSON.parse(text).map(w => {
                        const ws = Compositor.workspaces.find(x => x.id === w.workspace_id);
                        return {
                            id: w.id,
                            title: w.title ?? "",
                            appId: w.app_id ?? "",
                            ws: ws ? String(ws.idx) : "",
                            focused: !!w.is_focused,
                            stamp: w.focus_timestamp?.secs ?? 0
                        };
                    });
                } catch (err) {}
            }
        }
    }

    // ── Hyprland ──
    Process {
        id: hyprProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.list = JSON.parse(text)
                        .filter(c => c.mapped !== false && c.workspace && c.workspace.id > 0)
                        .map(c => ({
                            id: c.address,
                            title: c.title ?? "",
                            appId: c.class ?? "",
                            ws: String(c.workspace.id),
                            focused: c.focusHistoryID === 0,
                            stamp: -(c.focusHistoryID ?? 0)
                        }));
                } catch (err) {}
            }
        }
    }
}
