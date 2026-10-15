pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Applies a wallpaper by running matugen (your matugen config's hooks set the wallpaper
// and regenerate the colors). The last applied wallpaper is remembered across restarts.
Singleton {
    id: root

    // Settings > Appearance > Wallpaper folder (empty = ~/Pictures/wallpapers, leading ~ is expanded)
    readonly property string dir: {
        const home = Quickshell.env("HOME");
        const d = Settings.cfg.wallpaperDir.trim();
        if (d === "") return home + "/Pictures/wallpapers";
        if (d === "~") return home;
        if (d.startsWith("~/")) return home + d.slice(1);
        return d;
    }
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/quickshell-haze"
    readonly property string scheme: Settings.cfg.matugenScheme      // Settings > Colors
    readonly property real contrast: Settings.cfg.matugenContrast

    property string current: ""
    property string pending: ""
    property bool applying: false
    property bool ready: false

    function apply(path) {
        if (applying) return;
        pending = path;
        applying = true;
        proc.command = ["matugen", "--type", scheme, "--contrast", String(contrast), "image", path];
        proc.running = true;
    }

    Process {
        id: proc
        onExited: {
            root.applying = false;
            root.current = root.pending;
            if (root.ready) cur.setText(root.current);
        }
    }

    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
        onExited: root.ready = true
    }

    FileView {
        id: cur
        path: root.ready ? root.stateDir + "/wallpaper.txt" : ""
        printErrors: false
        onLoaded: root.current = text().trim()
    }
}
