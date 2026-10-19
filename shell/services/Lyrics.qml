pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Synced lyrics for the active player, from lrclib.net (no account, no key).
// Looks up the exact track first, then falls back to a search. Only works while a widget shows it
// (hold / release), results are remembered for the session. Needs curl.
Singleton {
    id: root

    readonly property var p: Players.active
    readonly property string api: "https://lrclib.net/api"
    readonly property string agent: "Haze (https://github.com/h4shcore/haze)"

    property int viewers: 0
    function hold() { viewers++; }
    function release() { viewers = Math.max(0, viewers - 1); }

    property string status: "idle"      // idle | loading | ready | none
    property var lines: []              // [{ t: seconds, s: "text" }]
    property string loadedKey: ""
    property var cache: ({})

    readonly property string artist: p?.trackArtist ?? ""
    readonly property string title: p?.trackTitle ?? ""
    readonly property string album: p?.trackAlbum ?? ""
    readonly property real duration: p?.length ?? 0
    readonly property string key: artist + "\u0001" + title

    // line that is being sung right now (-1 = before the first line)
    readonly property real pos: p?.position ?? 0
    readonly property int index: {
        const L = lines;
        const t = pos + 0.25;
        let lo = 0, hi = L.length - 1, ans = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (L[mid].t <= t) { ans = mid; lo = mid + 1; }
            else hi = mid - 1;
        }
        return ans;
    }

    readonly property bool ready: status === "ready"
    readonly property string cur: status === "ready" ? (index >= 0 ? (lines[index].s || "♪") : "♪")
        : status === "loading" ? "Looking for lyrics…"
        : status === "none" ? "No synced lyrics" : ""
    readonly property string prev: ready && index > 0 ? lines[index - 1].s : ""
    readonly property string next: ready && index + 1 < lines.length ? lines[index + 1].s : ""

    onKeyChanged: debounce.restart()
    onViewersChanged: if (viewers > 0 && loadedKey !== key) debounce.restart()

    // let the player finish filling in its metadata before asking
    Timer {
        id: debounce
        interval: 500
        onTriggered: root.load()
    }

    function enc(s) { return encodeURIComponent(s); }

    // "Song (feat. X) - Remastered 2011" -> "Song"
    function clean(t) {
        return t.replace(/\s*[\(\[].*?[\)\]]/g, "").replace(/\s+-\s+.*$/, "").trim();
    }

    function parse(synced) {
        const out = [];
        for (const raw of synced.split("\n")) {
            const m = raw.match(/^\s*((?:\[\d+:\d+(?:\.\d+)?\])+)\s*(.*)$/);
            if (!m) continue;
            const text = m[2].trim();
            const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
            let tm;
            while ((tm = re.exec(m[1])) !== null)
                out.push({ t: parseInt(tm[1]) * 60 + parseFloat(tm[2]), s: text });
        }
        out.sort((a, b) => a.t - b.t);
        return out;
    }

    function finish(k, list) {
        const c = root.cache;
        c[k] = list;
        root.cache = c;
        if (k !== key) return;
        lines = list;
        status = list.length > 0 ? "ready" : "none";
    }

    function request(k, stage, url) {
        const proc = fetcher.createObject(root, { reqKey: k, stage: stage });
        proc.command = ["curl", "-fsS", "--max-time", "8", "-A", agent, url];
        proc.running = true;
    }

    function handle(k, stage, text) {
        if (k !== key) return;      // the song changed while we were asking
        let obj = null;
        try { obj = JSON.parse(text); } catch (err) {}
        let synced = "";
        if (stage === "get") synced = obj?.syncedLyrics ?? "";
        else if (Array.isArray(obj)) synced = (obj.find(o => o.syncedLyrics) ?? {}).syncedLyrics ?? "";
        if (synced !== "") { finish(k, parse(synced)); return; }
        if (stage === "get") {
            request(k, "search", api + "/search?track_name=" + enc(clean(title)) + "&artist_name=" + enc(artist));
        } else {
            finish(k, []);
        }
    }

    function load() {
        if (viewers <= 0) return;
        if (title === "") {
            lines = [];
            status = "idle";
            loadedKey = "";
            return;
        }
        if (key === loadedKey) return;
        loadedKey = key;
        lines = [];
        if (cache[key] !== undefined) {
            lines = cache[key];
            status = lines.length > 0 ? "ready" : "none";
            return;
        }
        status = "loading";
        let url = api + "/get?track_name=" + enc(title) + "&artist_name=" + enc(artist);
        if (album !== "") url += "&album_name=" + enc(album);
        if (duration > 0) url += "&duration=" + Math.round(duration);
        request(key, "get", url);
    }

    Component {
        id: fetcher

        Process {
            id: pr

            property string reqKey
            property string stage

            stdout: StdioCollector {
                onStreamFinished: root.handle(pr.reqKey, pr.stage, text)
            }
            onExited: pr.destroy(3000)
        }
    }
}
