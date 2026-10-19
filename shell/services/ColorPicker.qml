pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen color picker: `niri msg pick-color` on Niri, `hyprpicker` on Hyprland (install it yourself).
// The picked color is copied as #rrggbb and shown in a notification.
Singleton {
    id: root

    property bool picking: false

    readonly property string script: [
        'if [ "$1" = hyprland ]; then',
        '  c=$(hyprpicker 2>/dev/null | grep -io \'#[0-9a-f]\\{6\\}\' | head -n1)',
        'else',
        '  c=$(niri msg pick-color 2>/dev/null | grep -io \'#[0-9a-f]\\{6\\}\' | head -n1)',
        'fi',
        '[ -n "$c" ] || exit 0',
        'printf %s "$c" | wl-copy',
        'notify-send -a Haze "Color copied" "$c"'
    ].join("\n")

    function pick() {
        if (picking) return;
        picking = true;
        proc.running = true;
    }

    Process {
        id: proc
        command: ["sh", "-c", root.script, "haze", Compositor.kind]
        onExited: root.picking = false
    }
}
