pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification server + inbox, per-app mute and a history that survives restarts
// (~/.local/state/quickshell-haze/notif-history.json).
Singleton {
    id: root

    property list<Entry> list: []
    readonly property list<Entry> popups: list.filter(e => e.popup)
    readonly property int count: list.length
    property bool dnd: false

    // the entry whose inline-reply field is open (the notch window then takes keyboard focus)
    property var replying: null

    // ── mute ──
    readonly property var mutedList: Settings.cfg.mutedApps.split(",").map(s => s.trim()).filter(s => s !== "")

    function isMuted(app) {
        const a = (app ?? "").trim().toLowerCase();
        return a !== "" && mutedList.some(m => m.toLowerCase() === a);
    }

    function mute(app) {
        app = (app ?? "").trim();
        if (app === "" || isMuted(app)) return;
        Settings.set("mutedApps", mutedList.concat([app]).join(", "));
        for (const e of list)
            if (isMuted(e.notif.appName) || e.notif.appName === app) e.popup = false;
    }

    function unmute(app) {
        const a = (app ?? "").trim().toLowerCase();
        Settings.set("mutedApps", mutedList.filter(m => m.toLowerCase() !== a).join(", "));
    }

    function toggleMute(app) {
        if (isMuted(app)) unmute(app);
        else mute(app);
    }

    // ── history ──
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/quickshell-haze"
    property bool ready: false

    // [{ id, app, summary, body, icon, time, urgency }], newest first
    readonly property var history: {
        try {
            const v = JSON.parse(store.adapter.json || "[]");
            return Array.isArray(v) ? v : [];
        } catch (err) { return []; }
    }

    function saveHistory(items) {
        store.adapter.json = JSON.stringify(items.slice(0, Math.max(1, Settings.cfg.notifHistoryMax)));
        if (ready) store.writeAdapter();
    }

    function record(n) {
        if (!Settings.cfg.notifHistory) return;
        const item = {
            id: Date.now() + "-" + n.id,
            app: n.appName ?? "",
            summary: n.summary ?? "",
            body: n.body ?? "",
            icon: n.appIcon ?? "",
            time: Date.now(),
            urgency: n.urgency === NotificationUrgency.Critical ? 2 : 1
        };
        saveHistory([item].concat(history));
    }

    function removeHistory(id) { saveHistory(history.filter(h => h.id !== id)); }
    function clearHistory() { saveHistory([]); }

    function clearAll() {
        for (const e of list.filter(() => true))
            e.notif.dismiss();
    }

    Process {
        command: ["mkdir", "-p", root.dir]
        running: true
        onExited: root.ready = true
    }

    FileView {
        id: store
        path: root.ready ? root.dir + "/notif-history.json" : ""
        printErrors: false
        adapter: JsonAdapter {
            property string json: "[]"
        }
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true

        onNotification: n => {
            n.tracked = true;
            root.record(n);
            root.list = [entryComp.createObject(root, { notif: n }), ...root.list];
        }
    }

    Component {
        id: entryComp
        Entry {}
    }

    component Entry: QtObject {
        id: entry

        required property Notification notif
        readonly property bool critical: notif.urgency === NotificationUrgency.Critical
        // muted apps get no toast (critical ones still do), they stay in the inbox
        property bool popup: !root.dnd && (critical || !root.isMuted(notif.appName))

        readonly property Timer timer: Timer {
            running: entry.popup && !entry.critical && root.replying !== entry
            interval: entry.notif.expireTimeout > 0 ? entry.notif.expireTimeout * 1000 : 6000
            onTriggered: entry.popup = false
        }

        readonly property Connections conn: Connections {
            target: entry.notif
            function onClosed() {
                if (root.replying === entry) root.replying = null;
                root.list = root.list.filter(e => e !== entry);
                entry.destroy(1500);
            }
        }
    }
}
