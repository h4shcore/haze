pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Caffeine: while on, holds a systemd idle+sleep inhibitor so the screen doesn't lock or suspend.
// Turning it off (or quitting Haze) kills the inhibitor.
Singleton {
    id: root

    property bool active: false

    function toggle() { active = !active; }

    Process {
        running: root.active
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Haze", "--why=Caffeine", "--mode=block", "sleep", "infinity"]
        onExited: if (root.active) root.active = false   // inhibitor died unexpectedly
    }
}
