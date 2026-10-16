pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User settings, edited from the Settings dock and applied live.
//
// Stored in ~/.config/quickshell/haze-settings.json (only values that differ from the defaults),
// next to colors.json, so it stays outside the Nix store.
//
// Read a value anywhere with:   Settings.cfg.clock24h
// Change one from code with:    Settings.set("clock24h", false)
//
// TO ADD A NEW SETTING:
//   1. add `key: defaultValue` to `defaults` below (the type of the default is the type of the setting)
//   2. use `Settings.cfg.key` wherever it should take effect
//   3. add one line for it in `pages` in modules/SettingsWindow.qml so it shows up in the GUI
Singleton {
    id: root

    readonly property var defaults: ({
        // modules
        showWorkspaces: true,
        showTray: true,
        showToasts: true,
        showTodo: true,
        showOsd: true,
        // clock
        clock24h: true,
        clockSeconds: false,
        dateFormat: "ddd d MMM",
        // shape
        borderThickness: 4,
        notchRadius: 16,
        panelRadius: 24,
        // typeface (any installed font family)
        fontFamily: "Rubik",
        extraFonts: "",       // comma-separated families to offer in Settings
        // control center
        ccWidth: 420,
        ccShowMedia: true,
        ccShowSysMon: true,
        ccShowShortcuts: true,

        widgetClock: false,   // desktop widgets (modules/WidgetsLayer.qml); X / Y = -1 means the default spot
        widgetClockX: -1,
        widgetClockY: -1,
        widgetMedia: false,
        widgetMediaX: -1,
        widgetMediaY: -1,
        widgetSysmon: false,
        widgetSysmonX: -1,
        widgetSysmonY: -1,
        widgetTodo: false,
        widgetTodoX: -1,
        widgetTodoY: -1,

        settingsX: 0,         // window offsets from their default spot (drag the title to move)
        settingsY: 0,
        todoX: 0,
        todoY: 0,
        // colors (matugen, used the next time a wallpaper is applied)
        matugenScheme: "scheme-smart",
        matugenContrast: 0.5,
        accent: "",           // "#rrggbb" overrides the wallpaper accent, empty = from wallpaper
        // wallpapers
        wallpaperDir: ""      // empty = ~/Pictures/wallpapers
    })

    // overrides loaded from disk
    property var data: ({})

    // defaults + overrides, type-checked so a hand-edited file can't break the shell
    readonly property var cfg: {
        const out = {};
        for (const k in defaults) {
            const v = data[k];
            out[k] = (v !== undefined && typeof v === typeof defaults[k]) ? v : defaults[k];
        }
        return out;
    }

    property bool loaded: false
    property string lastWritten: ""

    function set(key, value) {
        if (!(key in defaults)) return;
        const d = Object.assign({}, data);
        d[key] = value;
        data = d;
        saveTimer.restart();
    }

    function reset(keys) {
        const d = Object.assign({}, data);
        keys.forEach(k => delete d[k]);
        data = d;
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            if (!root.loaded) return;
            root.lastWritten = JSON.stringify(root.data, null, 2);
            store.setText(root.lastWritten);
        }
    }

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.config/quickshell/haze-settings.json"
        watchChanges: true
        printErrors: false

        onLoaded: {
            const t = text();
            if (t === root.lastWritten) return;   // our own write echoing back
            try { root.data = JSON.parse(t); } catch (err) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true          // no file yet: defaults
        onFileChanged: reload()
    }
}
