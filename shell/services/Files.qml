pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// File search for the launcher's "/" mode: names under $HOME, hidden folders skipped.
// Uses `fd` when installed, else `find`. Results stream in while it searches.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    property string query: ""
    property var results: []
    property bool searching: false
    property int seq: 0
    property var buf: []

    readonly property string script: [
        'seq="$1"; q="$2"',
        '[ -n "$q" ] || exit 0',
        '{',
        '  if command -v fd >/dev/null 2>&1; then',
        '    fd --max-results 80 --type f --type d -i -F -- "$q" "$HOME" 2>/dev/null',
        '  else',
        '    find "$HOME" -path \'*/.*\' -prune -o -iname "*$q*" -print 2>/dev/null | head -n 80',
        '  fi',
        '} | while IFS= read -r p; do',
        '  if [ -d "$p" ]; then t=d; else t=f; fi',
        '  printf \'%s\\t%s\\t%s\\n\' "$seq" "$t" "$p"',
        'done'
    ].join("\n")

    onQueryChanged: debounce.restart()

    Timer {
        id: debounce
        interval: 160
        onTriggered: root.run()
    }

    function run() {
        proc.running = false;      // stop a search that is still going
        seq++;
        buf = [];
        if (query.length < 2) {
            results = [];
            searching = false;
            return;
        }
        searching = true;
        proc.command = ["sh", "-c", script, "haze", String(seq), query];
        proc.running = true;
    }

    function take(line) {
        const parts = line.split("\t");
        if (parts.length < 3 || parts[0] !== String(seq)) return;
        const p = parts.slice(2).join("\t");
        const i = p.lastIndexOf("/");
        const parent = p.slice(0, i);
        buf.push({
            id: "file:" + p,
            kind: "file",
            path: p,
            dir: parts[1] === "d",
            title: p.slice(i + 1),
            subtitle: parent.startsWith(home) ? "~" + parent.slice(home.length) : parent
        });
        flush.start();
    }

    // name matches that start with the query first, then shorter paths
    Timer {
        id: flush
        interval: 70
        onTriggered: {
            const q = root.query.toLowerCase();
            root.results = root.buf.slice().sort((a, b) =>
                (b.title.toLowerCase().startsWith(q) - a.title.toLowerCase().startsWith(q))
                || (a.path.length - b.path.length));
        }
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => root.take(line)
        }
        onExited: root.searching = false
    }
}
