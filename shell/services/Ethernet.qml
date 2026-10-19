pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wired adapters via nmcli (NetworkManager): link state, IP / gateway / DNS, link speed, live throughput,
// connect / disconnect, auto-connect and switching a profile between DHCP and a manual address.
// Only polls while the Settings panel is open (`wantDetails`).
Singleton {
    id: root

    property bool wantDetails: false
    property var devices: []          // ethernet device names, e.g. ["enp3s0"]
    property var status: ({})         // name -> { state, connection }
    property var details: ({})        // name -> { mac, ip, gateway, dns, speed, method, auto }
    property var rates: ({})          // name -> { down, up, rx, tx }
    property string error: ""
    property bool busy: false
    property var prevSamples: ({})

    readonly property bool available: devices.length > 0

    // everything the panel needs about one device
    function get(name) {
        const s = status[name] ?? {};
        const d = details[name] ?? {};
        const r = rates[name] ?? {};
        return {
            name: name,
            state: s.state ?? "disconnected",
            connection: s.connection ?? "",
            mac: d.mac ?? "",
            ip: d.ip ?? "",
            gateway: d.gateway ?? "",
            dns: d.dns ?? [],
            speed: d.speed ?? "",
            method: d.method ?? "",
            auto: d.auto === true,
            down: r.down ?? 0,
            up: r.up ?? 0,
            rx: r.rx ?? 0,
            tx: r.tx ?? 0
        };
    }

    function refreshAll() {
        if (!listProc.running) listProc.running = true;
        if (!infoProc.running) infoProc.running = true;
    }

    onWantDetailsChanged: {
        if (wantDetails) return;
        prevSamples = ({});
        rates = ({});
    }

    // run an nmcli command; the last error line lands in `error`
    function run(args) {
        if (job.running) return;
        error = "";
        busy = true;
        job.command = ["sh", "-c", 'c=0; out=$("$@" 2>&1) || c=$?; printf "%s|%s" "$c" "$out"', "sh"].concat(args);
        job.running = true;
    }

    function connect(dev) { run(["nmcli", "device", "connect", dev]); }
    function disconnect(dev) { run(["nmcli", "device", "disconnect", dev]); }
    function setAuto(profile, on) { run(["nmcli", "connection", "modify", "id", profile, "connection.autoconnect", on ? "yes" : "no"]); }

    function setAutoIp(profile) {
        run(["sh", "-c", 'nmcli connection modify id "$1" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns "" && nmcli connection up id "$1"', "sh", profile]);
    }

    function setManual(profile, addr, gateway, dns) {
        addr = addr.trim();
        gateway = gateway.trim();
        if (!/^\d{1,3}(\.\d{1,3}){3}\/\d{1,2}$/.test(addr)) {
            error = "Address needs a prefix, like 192.168.1.10/24";
            return;
        }
        if (gateway !== "" && !/^\d{1,3}(\.\d{1,3}){3}$/.test(gateway)) {
            error = "Gateway should look like 192.168.1.1";
            return;
        }
        run(["sh", "-c", 'nmcli connection modify id "$1" ipv4.method manual ipv4.addresses "$2" ipv4.gateway "$3" ipv4.dns "$4" && nmcli connection up id "$1"',
            "sh", profile, addr, gateway, dns.replace(/,/g, " ").trim()]);
    }

    function unescape(v) { return v.replace(/\\:/g, ":"); }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                const st = {};
                for (const line of text.split("\n")) {
                    if (line === "") continue;
                    const f = Network.splitTerse(line);
                    if (f.length < 4 || f[1] !== "ethernet") continue;
                    const raw = f[2];
                    names.push(f[0]);
                    st[f[0]] = {
                        state: raw.startsWith("connected") ? "connected" : raw.startsWith("connecting") ? "connecting"
                            : raw === "unavailable" ? "unavailable" : "disconnected",
                        connection: f[3] === "--" ? "" : f[3]
                    };
                }
                root.status = st;
                if (JSON.stringify(names) !== JSON.stringify(root.devices)) root.devices = names;
            }
        }
    }

    Process {
        id: infoProc
        command: ["sh", "-c", [
            'for d in $(nmcli -t -f DEVICE,TYPE dev | awk -F: \'$2=="ethernet"{print $1}\'); do',
            '  echo "DEV:$d"',
            '  nmcli -t -f GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS dev show "$d"',
            '  echo "SPEED:$(cat /sys/class/net/$d/speed 2>/dev/null)"',
            '  c=$(nmcli -g GENERAL.CONNECTION dev show "$d")',
            '  if [ -n "$c" ] && [ "$c" != "--" ]; then',
            '    echo "METHOD:$(nmcli -g ipv4.method connection show id "$c")"',
            '    echo "AUTO:$(nmcli -g connection.autoconnect connection show id "$c")"',
            '  fi',
            'done'
        ].join("\n")]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                let cur = null;
                for (const line of text.split("\n")) {
                    if (line.startsWith("DEV:")) {
                        cur = { mac: "", ip: "", gateway: "", dns: [], speed: "", method: "", auto: false };
                        out[line.slice(4)] = cur;
                        continue;
                    }
                    if (!cur) continue;
                    const i = line.indexOf(":");
                    if (i < 0) continue;
                    const k = line.slice(0, i);
                    const v = line.slice(i + 1);
                    if (k === "GENERAL.HWADDR") cur.mac = root.unescape(v);
                    else if (k.startsWith("IP4.ADDRESS") && cur.ip === "") cur.ip = v;
                    else if (k === "IP4.GATEWAY") cur.gateway = v;
                    else if (k.startsWith("IP4.DNS")) cur.dns.push(v);
                    else if (k === "SPEED") {
                        const n = parseInt(v);
                        cur.speed = n > 0 ? (n >= 1000 ? (n / 1000) + " Gbit/s" : n + " Mbit/s") : "";
                    }
                    else if (k === "METHOD") cur.method = v;
                    else if (k === "AUTO") cur.auto = v === "yes";
                }
                root.details = out;
            }
        }
    }

    Process {
        id: rateProc
        command: ["cat", "/proc/net/dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = Date.now();
                const out = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf(":");
                    if (i < 0) continue;
                    const name = line.slice(0, i).trim();
                    if (root.devices.indexOf(name) < 0) continue;
                    const f = line.slice(i + 1).trim().split(/\s+/).map(Number);
                    const rx = f[0], tx = f[8];
                    const p = root.prevSamples[name];
                    if (p && t > p.t) {
                        const dt = (t - p.t) / 1000;
                        out[name] = { down: Math.max(0, (rx - p.rx) / dt), up: Math.max(0, (tx - p.tx) / dt), rx: rx, tx: tx };
                    } else out[name] = { down: 0, up: 0, rx: rx, tx: tx };
                    root.prevSamples[name] = { rx: rx, tx: tx, t: t };
                }
                root.rates = out;
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

    Timer {
        interval: 10000
        repeat: true
        running: root.wantDetails
        onTriggered: root.refreshAll()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.wantDetails && root.devices.length > 0
        onTriggered: if (!rateProc.running) rateProc.running = true
    }
}
