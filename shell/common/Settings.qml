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
        frameRadius: 18,          // inner corner radius of the screen border
        earRadius: 10,            // concave corners where the notch and docks meet the border
        barHeight: 38,            // collapsed notch height, also the top docks and the space tiled windows leave
        // bar & notch
        clockSize: 14,            // px, the date is one px smaller
        clockBold: true,
        showBattery: true,
        showBell: true,
        notchOpenOn: "hover",     // "hover" or "click"
        notchOpenDelay: 0,        // ms the pointer must rest on the notch before it opens (hover mode)
        notchCloseDelay: 350,     // ms after the pointer leaves before it closes
        songToast: true,          // show the track in the notch when it changes
        songToastSeconds: 3,
        scrimDim: 35,             // % the screen dims while the launcher is open
        // typeface (any installed font family)
        fontFamily: "Rubik",
        extraFonts: "",       // comma-separated families to offer in Settings
        // control center
        ccWidth: 420,
        ccShowMedia: true,
        ccShowSysMon: true,
        ccShowShortcuts: true,
        ccOrder: "tiles,media,shortcuts",   // top to bottom
        ccTiles: "wifi,bt,focus,inbox,night",   // toggles shown, in order (leave one out to hide it)
        ccShortcuts: "apps,clip,wall,cap,power,caf,pwr,set",   // shortcut strip buttons, in order
        ccTilesHeight: 176,       // px, height of the toggle area
        ccStripHeight: 48,        // px, height of the shortcut strip
        ccGap: 10,                // px between cards
        ccCardRadius: 18,         // px, corners of the toggles (media card and strip are 6 px rounder)
        ccTileSubtitles: true,
        ccShowSliders: true,
        ccSlidersSide: "right",   // "left" or "right"
        ccSysMonSide: "right",
        ccSysMonWidth: 130,
        nightLightTemp: 4000,     // Kelvin, lower = warmer

        widgetClock: false,   // desktop widgets (modules/WidgetsLayer.qml); X / Y = -1 means the default spot
        widgetClockX: -1,
        widgetClockY: -1,
        widgetClockSize: "medium",   // "small" (time only, 160x160) or "medium" (340x160)
        widgetClockStacked: false,   // small clock: hours over minutes instead of one line
        widgetMedia: false,
        widgetMediaX: -1,
        widgetMediaY: -1,
        widgetMediaHideIdle: false,  // true = hide the Now playing widget while no player is open (false = skeleton)
        widgetMediaSize: "medium",   // "small" (album art only, 160x160), "medium" (340x160) or "large" (340x340, lyrics + spectrum)
        widgetMediaLyrics: true,     // synced lyrics from lrclib.net (medium: current line, large: three lines)
        widgetMediaViz: true,        // cava audio spectrum
        widgetFont: "SF Pro Display",   // macOS-style typeface for the desktop widgets; falls back to Inter, then the shell font
        widgetSysmon: false,
        widgetSysmonX: -1,
        widgetSysmonY: -1,
        widgetTodo: false,
        widgetTodoX: -1,
        widgetTodoY: -1,

        // notifications (services/Notifs.qml)
        notifHistory: true,        // keep a history that survives restarts
        notifHistoryMax: 100,
        mutedApps: "",             // comma-separated app names: no toasts, still in the inbox

        // launcher
        launcherSearchEngine: "ddg",   // default engine for "?" (ddg | google | brave)

        // lock screen (services/Lock.qml, modules/LockScreen.qml)
        lockOnIdle: true,
        lockIdleMinutes: 10,
        lockScreenOff: true,        // turn the monitors off a while after locking
        lockScreenOffSeconds: 30,
        lockBlur: true,
        lockPam: "login",           // PAM service used to check the password (/etc/pam.d/<name>)

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

    // A comma-separated list setting as an array. Unknown names and repeats are dropped; keepAll appends
    // any name from `all` that is missing, so an ordering can never lose an item (used for ccOrder).
    function listOf(key, all, keepAll) {
        const out = [];
        String(cfg[key]).split(",").forEach(s => {
            const k = s.trim();
            if (all.indexOf(k) >= 0 && out.indexOf(k) < 0) out.push(k);
        });
        if (keepAll) all.forEach(k => { if (out.indexOf(k) < 0) out.push(k); });
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
