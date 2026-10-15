pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Todo list for the bottom-left dock, persisted to ~/.local/state/quickshell-haze/todos.json.
// Open items first, finished ones sink to the bottom.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/quickshell-haze"
    property bool ready: false

    // [{ t: "text", done: false }, ...]
    readonly property var items: {
        try {
            const v = JSON.parse(store.adapter.json || "[]");
            return Array.isArray(v) ? v : [];
        } catch (err) { return []; }
    }
    readonly property int remaining: items.filter(i => !i.done).length
    readonly property int doneCount: items.length - remaining

    function save(list) {
        store.adapter.json = JSON.stringify(list.slice(0, 100));
        if (ready) store.writeAdapter();
    }

    function copy() { return items.map(i => ({ t: i.t, done: !!i.done })); }

    // keeps open items above finished ones
    function place(list, item) {
        const f = list.findIndex(x => x.done);
        list.splice(item.done || f < 0 ? list.length : f, 0, item);
    }

    function add(text) {
        text = (text ?? "").trim();
        if (text === "") return;
        const list = copy();
        place(list, { t: text, done: false });
        save(list);
    }

    function toggle(i) {
        const list = copy();
        if (i < 0 || i >= list.length) return;
        const item = list.splice(i, 1)[0];
        item.done = !item.done;
        place(list, item);
        save(list);
    }

    function remove(i) {
        const list = copy();
        list.splice(i, 1);
        save(list);
    }

    function clearDone() { save(copy().filter(i => !i.done)); }

    Process {
        command: ["mkdir", "-p", root.dir]
        running: true
        onExited: root.ready = true
    }

    FileView {
        id: store
        path: root.ready ? root.dir + "/todos.json" : ""
        printErrors: false
        adapter: JsonAdapter {
            property string json: "[]"
        }
    }
}
