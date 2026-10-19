pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Audio spectrum from cava, for the media widget. Runs only while something shows it (hold / release)
// and a player is playing. Without cava installed it just stays empty.
Singleton {
    id: root

    readonly property int bars: 28
    property var values: []           // 0..1 per bar

    property int viewers: 0
    function hold() { viewers++; }
    function release() { viewers = Math.max(0, viewers - 1); }

    readonly property bool wanted: viewers > 0 && (Players.active?.isPlaying ?? false)

    readonly property string script: [
        'c="${XDG_RUNTIME_DIR:-/tmp}/haze-cava.conf"',
        'cat > "$c" <<EOF2',
        '[general]',
        'bars = ' + bars,
        'framerate = 30',
        '[output]',
        'method = raw',
        'raw_target = /dev/stdout',
        'data_format = ascii',
        'ascii_max_range = 100',
        'bar_delimiter = 59',
        'frame_delimiter = 10',
        'EOF2',
        'exec cava -p "$c"'
    ].join("\n")

    Process {
        running: root.wanted
        command: ["sh", "-c", root.script]
        stdout: SplitParser {
            onRead: line => {
                const out = [];
                for (const p of line.split(";")) {
                    if (p === "") continue;
                    out.push(Math.min(1, parseInt(p) / 100));
                }
                root.values = out;
            }
        }
        onExited: root.values = []
    }
}
