pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Power profile via power-profiles-daemon (`powerprofilesctl`). Hidden when it isn't installed.
Singleton {
    id: root

    property bool available: false
    property string profile: "balanced"
    property var profiles: []

    readonly property string label: ({
        "power-saver": "Saver",
        "balanced": "Balanced",
        "performance": "Performance"
    })[profile] ?? profile

    readonly property string glyph: profile === "power-saver" ? "eco"
        : profile === "performance" ? "bolt" : "speed"

    // power-saver -> balanced -> performance -> power-saver
    function cycle() {
        if (profiles.length === 0) return;
        const next = profiles[(profiles.indexOf(profile) + 1) % profiles.length];
        profile = next;
        setProc.command = ["powerprofilesctl", "set", next];
        setProc.running = true;
    }

    function refresh() { listProc.running = true; }

    Process {
        id: listProc
        command: ["sh", "-c", "powerprofilesctl list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                let active = "";
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\*?)\s*([a-z-]+):\s*$/);
                    if (!m) continue;
                    names.push(m[2]);
                    if (m[1] === "*") active = m[2];
                }
                root.profiles = names;
                root.available = names.length > 0;
                if (active !== "") root.profile = active;
            }
        }
    }

    Process {
        id: setProc
        onExited: settle.restart()
    }

    Timer {
        id: settle
        interval: 500
        onTriggered: root.refresh()
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
