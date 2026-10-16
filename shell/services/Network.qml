pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wifi via nmcli (NetworkManager): radio state, scan list, connect / disconnect.
Singleton {
    id: root

    property bool enabled: false
    property string ssid: ""

    // scan results + saved wifi profiles -> `networks`
    property var raw: []        // [{ ssid, signal, secure, active }]
    property var known: []      // saved profile names
    property string connecting: ""
    property string error: ""

    // deduped by ssid, active first, then strongest first
    readonly property var networks: {
        const by = {};
        for (const n of raw) {
            const cur = by[n.ssid];
            if (!cur || n.active || (!cur.active && n.signal > cur.signal)) by[n.ssid] = n;
        }
        return Object.values(by)
            .map(n => ({ ssid: n.ssid, signal: n.signal, secure: n.secure, active: n.active, known: known.indexOf(n.ssid) >= 0 }))
            .sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
    }

    // nmcli -t escapes ':' and '\' with a backslash
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) cur += line[++i];
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }

    function refresh() {
        radioProc.running = true;
        listProc.running = true;
    }

    // fresh scan for the menu: show the cached list now, update when the rescan lands
    function scan() {
        refresh();
        knownProc.running = true;
        rescanProc.running = true;
    }

    function toggle() {
        toggleProc.command = ["nmcli", "radio", "wifi", root.enabled ? "off" : "on"];
        toggleProc.running = true;
        root.enabled = !root.enabled;
    }

    function connect(name, password) {
        error = "";
        connecting = name;
        const args = ["dev", "wifi", "connect", name];
        if (password) args.push("password", password);
        run(args);
    }

    function disconnect(name) {
        error = "";
        run(["connection", "down", "id", name]);
    }

    function run(args) {
        if (actProc.running) return;
        actProc.command = ["sh", "-c", 'c=0; out=$(nmcli "$@" 2>&1) || c=$?; printf "%s|%s" "$c" "$out"', "sh"].concat(args);
        actProc.running = true;
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: root.enabled = text.trim() === "enabled"
        }
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line === "") continue;
                    const f = root.splitTerse(line);
                    if (f.length < 4 || f[1] === "") continue;
                    out.push({
                        ssid: f[1],
                        signal: parseInt(f[2]) || 0,
                        secure: f[3] !== "" && f[3] !== "--",
                        active: f[0] === "*"
                    });
                }
                root.raw = out;
                const a = out.find(n => n.active);
                root.ssid = a ? a.ssid : "";
            }
        }
    }

    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                for (const line of text.split("\n")) {
                    const f = root.splitTerse(line);
                    if (f.length >= 2 && f[1] === "802-11-wireless") names.push(f[0]);
                }
                root.known = names;
            }
        }
    }

    Process {
        id: rescanProc
        command: ["nmcli", "dev", "wifi", "rescan"]
        onExited: rescanSettle.restart()
    }

    // output is "<exit code>|<message>"
    Process {
        id: actProc
        stdout: StdioCollector {
            onStreamFinished: {
                const i = text.indexOf("|");
                const code = i < 0 ? "1" : text.slice(0, i);
                const msg = i < 0 ? text : text.slice(i + 1);
                root.connecting = "";
                if (code !== "0") {
                    const lines = msg.trim().split("\n").filter(l => l.trim() !== "");
                    const last = (lines[lines.length - 1] ?? "Failed").replace(/^Error:\s*/, "");
                    root.error = last.length > 80 ? last.slice(0, 77) + "…" : last;
                }
                knownProc.running = true;
                settle.restart();
            }
        }
    }

    Process {
        id: toggleProc
        onExited: settle.restart()
    }

    Timer {
        id: rescanSettle
        interval: 2500
        onTriggered: root.refresh()
    }

    Timer {
        id: settle
        interval: 1200
        onTriggered: root.refresh()
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
