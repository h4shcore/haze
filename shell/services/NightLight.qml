pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Night light: while on, gammastep holds a fixed color temperature (Settings > Control center).
// Needs a compositor with wlr-gamma-control (Hyprland and Niri have it).
// Turning it off (or quitting Haze) stops gammastep, which restores the normal colors.
Singleton {
    id: root

    property bool active: false
    readonly property int temp: Settings.cfg.nightLightTemp

    function toggle() { active = !active; }

    Process {
        running: root.active
        command: ["gammastep", "-O", String(root.temp)]
        onExited: if (root.active) root.active = false   // gammastep missing, or the compositor refused
    }
}
