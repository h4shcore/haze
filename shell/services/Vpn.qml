pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// VPN tile: a NetworkManager VPN / WireGuard connection that is up, else Tailscale (if its daemon runs),
// else the first NetworkManager VPN / WireGuard connection you have configured.
// Hidden when none of those exist. Tailscale needs `sudo tailscale set --operator=$USER` once.
Singleton {
    id: root

    property string kind: ""         // "nm" | "tailscale" | ""
    property bool active: false
    property bool busy: false
    property string name: ""         // NetworkManager connection to bring up / down

    // everything below feeds Settings → Connectivity → VPN
    property bool wantDetails: false      // that panel is open
    property var connections: []          // NetworkManager VPN / WireGuard profiles: [{ name, uuid, type, active, auto }]
    property var ts: null                 // parsed `tailscale status --json`, null without tailscale
    property string error: ""
    property string connecting: ""

    readonly property var tsInfo: {
        if (!ts) return null;
        const peers = Object.values(ts.Peer ?? {});
        return {
            state: ts.BackendState ?? "",
            tailnet: ts.CurrentTailnet?.Name ?? "",
            host: ts.Self?.HostName ?? "",
            ip: (ts.Self?.TailscaleIPs ?? [])[0] ?? "",
            online: peers.filter(p => p.Online).length,
            peers: peers.length,
            exits: peers.filter(p => p.ExitNodeOption).map(p => ({ name: p.HostName ?? p.DNSName ?? "", ip: (p.TailscaleIPs ?? [])[0] ?? "", on: p.ExitNode === true })),
            exitName: peers.find(p => p.ExitNode === true)?.HostName ?? ""
        };
    }

    readonly property bool available: kind !== ""
    readonly property string label: !available ? "" : active ? (kind === "tailscale" ? "Tailscale" : name) : "VPN"

    readonly property string script: [
        'if command -v tailscale >/dev/null 2>&1; then',
        '  s=$(tailscale status --json 2>/dev/null | sed -n \'s/.*"BackendState": *"\\([A-Za-z]*\\)".*/\\1/p\' | head -n1)',
        '  [ -n "$s" ] && echo "ts:$s"',
        'fi',
        'if command -v nmcli >/dev/null 2>&1; then',
        '  nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: \'$2=="vpn"||$2=="wireguard"{print "nmup:"$1; exit}\'',
        '  nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: \'$2=="vpn"||$2=="wireguard"{print "nmcfg:"$1; exit}\'',
        'fi'
    ].join("\n")

    function refresh() { if (!listProc.running) listProc.running = true; }

    function refreshAll() {
        refresh();
        if (!connProc.running) connProc.running = true;
        if (!tsProc.running) tsProc.running = true;
    }

    // run a command, report its error line in `error`, then refresh
    function run(args, name) {
        if (job.running) return;
        error = "";
        connecting = name ?? "";
        busy = true;
        job.command = ["sh", "-c", 'c=0; out=$("$@" 2>&1) || c=$?; printf "%s|%s" "$c" "$out"', "sh"].concat(args);
        job.running = true;
    }

    function connect(name) { run(["nmcli", "connection", "up", "id", name], name); }
    function disconnect(name) { run(["nmcli", "connection", "down", "id", name], name); }
    function setAuto(name, on) { run(["nmcli", "connection", "modify", "id", name, "connection.autoconnect", on ? "yes" : "no"], ""); }
    function remove(name) { run(["nmcli", "connection", "delete", "id", name], ""); }
    function importConfig(type, path) { run(["nmcli", "connection", "import", "type", type, "file", path], ""); }
    function tsSet(on) { run(["timeout", "20", "tailscale", on ? "up" : "down"], "tailscale"); }
    function tsExit(ip) { run(["tailscale", "set", "--exit-node=" + ip], "tailscale"); }

    function toggle() {
        if (!available || busy) return;
        busy = true;
        if (kind === "tailscale") act.command = ["timeout", "15", "tailscale", active ? "down" : "up"];
        else act.command = ["nmcli", "connection", active ? "down" : "up", "id", name];
        act.running = true;
    }

    Process {
        id: listProc
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                let ts = "", up = "", cfg = "";
                for (const l of text.split("\n")) {
                    if (l.startsWith("ts:")) ts = l.slice(3);
                    else if (l.startsWith("nmup:")) up = l.slice(5);
                    else if (l.startsWith("nmcfg:")) cfg = l.slice(6);
                }
                if (up !== "") {
                    root.kind = "nm"; root.active = true; root.name = up;
                } else if (ts !== "" && ts !== "NoState") {
                    root.kind = "tailscale"; root.active = ts === "Running"; root.name = "Tailscale";
                } else if (cfg !== "") {
                    root.kind = "nm"; root.active = false; root.name = cfg;
                } else {
                    root.kind = ""; root.active = false; root.name = "";
                }
            }
        }
    }

    Process {
        id: connProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE,AUTOCONNECT", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line === "") continue;
                    const f = Network.splitTerse(line);
                    if (f.length < 5 || (f[2] !== "vpn" && f[2] !== "wireguard")) continue;
                    out.push({ name: f[0], uuid: f[1], type: f[2] === "wireguard" ? "WireGuard" : "VPN", active: f[3] === "yes", auto: f[4] === "yes" });
                }
                out.sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name));
                root.connections = out;
            }
        }
    }

    Process {
        id: tsProc
        command: ["sh", "-c", "command -v tailscale >/dev/null 2>&1 && tailscale status --json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.ts = text.trim() === "" ? null : JSON.parse(text); }
                catch (e) { root.ts = null; }
            }
        }
    }

    // output is "<exit code>|<message>"
    Process {
        id: job
        stdout: StdioCollector {
            onStreamFinished: {
                const i = text.indexOf("|");
                const code = i < 0 ? "1" : text.slice(0, i);
                const msg = i < 0 ? text : text.slice(i + 1);
                root.connecting = "";
                root.busy = false;
                if (code !== "0") {
                    const lines = msg.trim().split("\n").filter(l => l.trim() !== "");
                    const last = (lines[lines.length - 1] ?? "Failed").replace(/^Error:\s*/, "");
                    root.error = last.length > 90 ? last.slice(0, 87) + "…" : last;
                }
                root.refreshAll();
            }
        }
    }

    Process {
        id: act
        onExited: {
            root.busy = false;
            root.refresh();
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refresh();
            if (root.wantDetails) root.refreshAll();
        }
    }
}
