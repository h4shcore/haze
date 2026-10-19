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
        onTriggered: root.refresh()
    }
}
