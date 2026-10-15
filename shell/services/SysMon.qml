pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU / RAM / temperature from /proc and /sys. Polls only while something is showing it
// (views call hold() when they appear and release() when they go away).
Singleton {
    id: root

    property real cpu: 0          // 0..1
    property real ram: 0          // 0..1
    property real ramUsedGb: 0
    property real ramTotalGb: 0
    property real temp: -1        // °C, -1 = no sensor found

    property int viewers: 0
    function hold() { viewers++; }
    function release() { viewers = Math.max(0, viewers - 1); }

    property var _prev: null

    readonly property string script: [
        'head -n1 /proc/stat',
        'awk \'/^MemTotal|^MemAvailable/ { print $1, $2 }\' /proc/meminfo',
        't=',
        'for h in /sys/class/hwmon/hwmon*; do',
        '  case "$(cat "$h/name" 2>/dev/null)" in coretemp|k10temp|zenpower|cpu_thermal) t=$(cat "$h/temp1_input" 2>/dev/null); break;; esac',
        'done',
        '[ -n "$t" ] || t=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)',
        'echo "TEMP ${t:--1}"'
    ].join("\n")

    Process {
        id: proc
        command: ["sh", "-c", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                let total = 0, avail = 0;
                for (const line of text.split("\n")) {
                    const p = line.trim().split(/\s+/);
                    if (p[0] === "cpu") {
                        const n = p.slice(1, 9).map(Number);
                        const sum = n.reduce((a, b) => a + b, 0);
                        const idle = n[3] + (n[4] || 0);
                        if (root._prev) {
                            const dt = sum - root._prev.sum;
                            if (dt > 0) root.cpu = Math.max(0, Math.min(1, 1 - (idle - root._prev.idle) / dt));
                        }
                        root._prev = { sum: sum, idle: idle };
                    } else if (p[0] === "MemTotal:") total = Number(p[1]);
                    else if (p[0] === "MemAvailable:") avail = Number(p[1]);
                    else if (p[0] === "TEMP") {
                        const t = Number(p[1]);
                        root.temp = t > 0 ? t / 1000 : -1;
                    }
                }
                if (total > 0) {
                    root.ram = (total - avail) / total;
                    root.ramTotalGb = total / 1048576;
                    root.ramUsedGb = (total - avail) / 1048576;
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: root.viewers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!proc.running) proc.running = true
    }
}
