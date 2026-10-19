pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wifi via nmcli (NetworkManager): radio state, scan list, connect / disconnect / forget, hidden networks,
// per-profile auto-connect and the IP details of the active connection.
Singleton {
    id: root

    property bool enabled: false
    property string ssid: ""

    // scan results + saved wifi profiles -> `networks`
    property var raw: []        // [{ ssid, signal, secure, active }]
    property var known: []      // saved profile names
    property string connecting: ""
    property string error: ""
    property bool scanning: false
    property bool wantDetails: false     // the Settings panel is open: also fetch IP / gateway / DNS
    property var autoMap: ({})           // profile name -> auto-connect on?
    property var info: ({ device: "", ip: "", gateway: "", dns: [] })

    // saved profiles that are not in range right now
    readonly property var saved: known.filter(k => !raw.some(n => n.ssid === k))

    // deduped by ssid, active first, then strongest first
    readonly property var networks: {
        const by = {};
        for (const n of raw) {
            const cur = by[n.ssid];
            if (!cur || n.active || (!cur.active && n.signal > cur.signal)) by[n.ssid] = n;
        }
        return Object.values(by)
            .map(n => ({
                ssid: n.ssid, signal: n.signal, secure: n.secure, active: n.active, known: known.indexOf(n.ssid) >= 0,
                security: n.security, band: n.band, rate: n.rate, chan: n.chan, bssid: n.bssid
            }))
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
        scanning = true;
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

    // join a network that does not broadcast its name
    function connectHidden(name, password) {
        error = "";
        connecting = name;
        const args = ["dev", "wifi", "connect", name];
        if (password) args.push("password", password);
        args.push("hidden", "yes");
        run(args);
    }

    // delete the saved profile (and its password)
    function forget(name) {
        error = "";
        run(["connection", "delete", "id", name]);
    }

    function setAuto(name, on) {
        if (actProc.running) return;
        error = "";
        autoMap = Object.assign({}, autoMap, { [name]: on });
        run(["connection", "modify", "id", name, "connection.autoconnect", on ? "yes" : "no"]);
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
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,FREQ,RATE,CHAN,BSSID", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line === "") continue;
                    const f = root.splitTerse(line);
                    if (f.length < 4 || f[1] === "") continue;
                    const freq = parseInt(f[4]) || 0;
                    out.push({
                        ssid: f[1],
                        signal: parseInt(f[2]) || 0,
                        secure: f[3] !== "" && f[3] !== "--",
                        security: f[3] === "--" ? "" : f[3],
                        band: freq >= 5925 ? "6 GHz" : freq >= 4900 ? "5 GHz" : freq > 0 ? "2.4 GHz" : "",
                        rate: f[5] ?? "",
                        chan: f[6] ?? "",
                        bssid: f[7] ?? "",
                        active: f[0] === "*"
                    });
                }
                root.raw = out;
                const a = out.find(n => n.active);
                root.ssid = a ? a.ssid : "";
                if (root.wantDetails && root.ssid !== "" && !infoProc.running) infoProc.running = true;
            }
        }
    }

    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,AUTOCONNECT", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                const auto = {};
                for (const line of text.split("\n")) {
                    const f = root.splitTerse(line);
                    if (f.length >= 3 && f[1] === "802-11-wireless") {
                        names.push(f[0]);
                        auto[f[0]] = f[2] === "yes";
                    }
                }
                root.known = names;
                root.autoMap = auto;
            }
        }
    }

    // IP / gateway / DNS of the connected wifi device
    Process {
        id: infoProc
        command: ["sh", "-c", [
            'd=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: \'$2=="wifi" && $3=="connected"{print $1; exit}\')',
            '[ -n "$d" ] && nmcli -t -f GENERAL.DEVICE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS dev show "$d"'
        ].join("\n")]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = { device: "", ip: "", gateway: "", dns: [] };
                for (const line of text.split("\n")) {
                    const i = line.indexOf(":");
                    if (i < 0) continue;
                    const k = line.slice(0, i);
                    const v = line.slice(i + 1);
                    if (k === "GENERAL.DEVICE") o.device = v;
                    else if (k.startsWith("IP4.ADDRESS") && o.ip === "") o.ip = v;
                    else if (k === "IP4.GATEWAY") o.gateway = v;
                    else if (k.startsWith("IP4.DNS")) o.dns.push(v);
                }
                root.info = o;
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
        onTriggered: {
            root.refresh();
            root.scanning = false;
        }
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
