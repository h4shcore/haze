pragma Singleton
import QtQuick
import Quickshell

// Quick timers for the launcher: "timer 10m", "timer 1h30m tea", "timer 90s", "timer 1:30" (mm:ss).
// A bare number is minutes. When one runs out Haze sends a critical notification.
Singleton {
    id: root

    property var list: []         // [{ id, label, end, total }]
    property real now: Date.now()
    property int nextId: 1

    // "1h30m", "90s", "10", "1:30", "1:02:03" -> milliseconds, or 0
    function parseDuration(s) {
        s = s.trim().toLowerCase();
        let m = /^(\d+):(\d{1,2})(?::(\d{1,2}))?$/.exec(s);
        if (m) {
            const a = parseInt(m[1]), b = parseInt(m[2]), c = m[3] !== undefined ? parseInt(m[3]) : -1;
            return (c < 0 ? a * 60 + b : a * 3600 + b * 60 + c) * 1000;
        }
        const re = /(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)?/g;
        let total = 0;
        let used = 0;
        while ((m = re.exec(s)) !== null) {
            const v = parseFloat(m[1]);
            const u = (m[2] ?? "m")[0];
            total += v * (u === "h" ? 3600 : u === "s" ? 1 : 60) * 1000;
            used += m[0].length;
        }
        return used > 0 && s.replace(/[\s\d.]|hours?|hrs?|minutes?|mins?|seconds?|secs?|[hms]/g, "") === "" ? Math.round(total) : 0;
    }

    // "10m tea" -> { ms: 600000, label: "tea" }, null if there is no time in it
    function parse(rest) {
        rest = rest.trim();
        const m = /^(\d+:\d{1,2}(?::\d{1,2})?|(?:\d+(?:\.\d+)?\s*(?:hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)?\s*)+)\s*(.*)$/i.exec(rest);
        if (!m) return null;
        const ms = parseDuration(m[1]);
        return ms > 0 ? { ms: ms, label: m[2].trim() } : null;
    }

    function fmt(ms) {
        const t = Math.max(0, Math.ceil(ms / 1000));
        const h = Math.floor(t / 3600), mi = Math.floor(t % 3600 / 60), s = t % 60;
        const p = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + p(mi) + ":" + p(s) : mi + ":" + p(s);
    }

    function start(ms, label) {
        const t = Date.now();
        root.now = t;
        root.list = root.list.concat([{ id: nextId++, label: label || "Timer", end: t + ms, total: ms }]);
    }

    function cancel(id) {
        root.list = root.list.filter(x => x.id !== id);
    }

    // launcher rows for a query starting with "timer"
    function rows(query) {
        const m = /^timer\b\s*(.*)$/i.exec((query ?? "").trim());
        if (!m) return [];
        const out = [];
        const p = parse(m[1]);
        if (p) {
            out.push({ id: "timer:new", kind: "timer", action: "start", ms: p.ms, label: p.label,
                title: "Start a timer for " + fmt(p.ms), subtitle: (p.label !== "" ? p.label + "  ·  " : "") + "Enter to start" });
        } else if (m[1].trim() === "") {
            out.push({ id: "timer:hint", kind: "timer", action: "hint",
                title: "Type a time", subtitle: "timer 10m  ·  timer 1h30m tea  ·  timer 90s  ·  timer 1:30" });
        }
        for (const t of list)
            out.push({ id: "timer:" + t.id, kind: "timer", action: "cancel", tid: t.id, end: t.end, label: t.label,
                title: t.label, subtitle: "Running  ·  Enter to cancel" });
        return out;
    }

    Timer {
        interval: 500
        repeat: true
        running: root.list.length > 0
        onTriggered: {
            root.now = Date.now();
            const done = root.list.filter(x => x.end <= root.now);
            if (done.length === 0) return;
            root.list = root.list.filter(x => x.end > root.now);
            for (const t of done)
                Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Haze timer", "Timer finished", t.label]);
        }
    }
}
