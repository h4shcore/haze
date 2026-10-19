import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Floating settings app: sidebar + search + grouped cards, everything applies live and is saved to
// ~/.config/quickshell/haze-settings.json.
//
// Esc close · / or Ctrl+F search · Alt+1…4 pages · drag the title to move (double-click it to re-center)
//
// To add an option: add it to Settings.defaults (common/Settings.qml), then add one line to `pages` below.
//   types: bool · enum (options: [{ v, l }], segmented) · chips (options, wraps) · text (placeholder) · int / real (min, max, step, unit)
//          action (action: id, button: text) · info (mono label) · preview
PanelWindow {
    id: win

    readonly property bool focusedHere: (Compositor.focusedOutput || screen.name) === screen.name
    property bool latched: false
    readonly property bool open: SettingsUi.open && latched

    // dragging: offsets from the centered spot, saved on drop
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    readonly property real offX: dragging ? dragX : Settings.cfg.settingsX
    readonly property real offY: dragging ? dragY : Settings.cfg.settingsY
    readonly property real homeX: (width - card.width) / 2
    readonly property real homeY: (height - card.height) / 2

    function clampX(v) { return Math.max(120 - card.width - homeX, Math.min(width - 120 - homeX, v)); }
    function clampY(v) { return Math.max(-homeY, Math.min(height - 80 - homeY, v)); }

    Connections {
        target: SettingsUi
        function onOpenChanged() {
            if (SettingsUi.open) {
                win.latched = win.focusedHere;
                search.text = "";
                win.pageIndex = 0;
                focusTimer.restart();
            }
        }
    }

    // Curated fonts, only the installed ones are offered. The current value is always listed,
    // and any family name can be set by hand in haze-settings.json ("fontFamily").
    readonly property var fontChoices: {
        const extra = Settings.cfg.extraFonts.split(",").map(s => s.trim()).filter(s => s !== "");
        const wanted = ["Rubik", "Inter", "Geist", "JetBrains Mono", "Maple Mono NF", "Noto Sans"]
            .concat(extra).filter((f, i, a) => a.indexOf(f) === i);
        const have = Qt.fontFamilies();
        const out = wanted.filter(f => have.indexOf(f) >= 0).map(f => ({ v: f, l: f }));
        const cur = Settings.cfg.fontFamily;
        if (!out.some(o => o.v === cur)) out.unshift({ v: cur, l: cur });
        return out;
    }

    // Widget typefaces: the macOS-style ones first, only installed families are offered
    readonly property var widgetFontChoices: {
        const have = Qt.fontFamilies();
        const out = ["SF Pro Display", "Inter", "Helvetica Neue", "Geist", "Rubik"]
            .filter(f => have.indexOf(f) >= 0).map(f => ({ v: f, l: f }));
        out.push({ v: "", l: "Same as shell" });
        const cur = Settings.cfg.widgetFont;
        if (cur !== "" && !out.some(o => o.v === cur)) out.unshift({ v: cur, l: cur });
        return out;
    }

    readonly property var pages: [
        { id: "appearance", label: "Appearance", glyph: "\uf1fc", title: "Appearance", sub: "How the shell is shaped and colored", sections: [
            { title: "Preview", items: [ { type: "preview" } ] },
            { title: "Shape", items: [
                { key: "borderThickness", type: "int", label: "Border thickness", hint: "The frame around the screen", min: 2, max: 10, step: 1, unit: " px" },
                { key: "notchRadius", type: "int", label: "Notch corners", hint: "Collapsed notch", min: 6, max: 26, step: 1, unit: " px" },
                { key: "panelRadius", type: "int", label: "Expanded corners", hint: "Control center and calendar", min: 12, max: 36, step: 1, unit: " px" }
            ] },
            { title: "Font", items: [
                { key: "fontFamily", type: "chips", label: "Typeface", hint: "Installed fonts only", options: win.fontChoices },
                { key: "extraFonts", type: "text", label: "More fonts", hint: "Family names to offer above, comma-separated. Press Enter to apply", placeholder: "Outfit, Manrope" }
            ] },
            { title: "Wallpaper", items: [
                { key: "wallpaperDir", type: "text", label: "Wallpaper folder", hint: "Where the picker looks. Empty uses ~/Pictures/wallpapers", placeholder: "~/Pictures/wallpapers" }
            ] },
            { title: "Colors", items: [
                { key: "matugenScheme", type: "chips", label: "Color scheme", hint: "Used the next time a wallpaper is applied", options: [
                    { v: "scheme-smart", l: "Smart" },
                    { v: "scheme-tonal-spot", l: "Tonal spot" },
                    { v: "scheme-vibrant", l: "Vibrant" },
                    { v: "scheme-expressive", l: "Expressive" },
                    { v: "scheme-fidelity", l: "Fidelity" },
                    { v: "scheme-content", l: "Content" },
                    { v: "scheme-neutral", l: "Neutral" },
                    { v: "scheme-monochrome", l: "Monochrome" },
                    { v: "scheme-rainbow", l: "Rainbow" },
                    { v: "scheme-fruit-salad", l: "Fruit salad" }
                ] },
                { key: "matugenContrast", type: "real", label: "Contrast", hint: "Lower is softer, higher is punchier", min: -1, max: 1, step: 0.1 },
                { key: "accent", type: "text", label: "Accent color", hint: "Hex like #ff8a65. Empty follows the wallpaper", placeholder: "#rrggbb" },
                { type: "action", action: "reapply", label: "Re-apply wallpaper", hint: "Regenerate the colors with these settings", button: "Apply" }
            ] }
        ] },
        { id: "bar", label: "Bar & notch", glyph: "\uf2d0", title: "Bar & notch", sub: "The clock and the control center", sections: [
            { title: "Clock", items: [
                { key: "clock24h", type: "bool", label: "24-hour time", hint: "Off shows AM / PM" },
                { key: "clockSeconds", type: "bool", label: "Show seconds" },
                { key: "dateFormat", type: "enum", label: "Date", hint: "Next to the time", options: [
                    { v: "ddd d MMM", l: "Thu 15 Oct" },
                    { v: "d MMM", l: "15 Oct" },
                    { v: "MMM d", l: "Oct 15" },
                    { v: "dd/MM", l: "15/10" },
                    { v: "", l: "Hidden" }
                ] }
            ] },
            { title: "Control center", items: [
                { key: "ccWidth", type: "int", label: "Width", hint: "How wide the notch opens", min: 340, max: 520, step: 10, unit: " px" },
                { key: "ccShowMedia", type: "bool", label: "Now playing card" },
                { key: "ccShowSysMon", type: "bool", label: "System monitor", hint: "CPU, memory and temperature, right of the control center" },
                { key: "ccShowShortcuts", type: "bool", label: "Shortcut strip", hint: "Launcher, clipboard, wallpapers, capture, power" }
            ] }
        ] },
        { id: "modules", label: "Modules", glyph: "\uf009", title: "Modules", sub: "Turn the docks around the border on or off", sections: [
            { title: "Docks", items: [
                { key: "showWorkspaces", type: "bool", label: "Workspaces", hint: "Top-left" },
                { key: "showTray", type: "bool", label: "System tray", hint: "Top-right" },
                { key: "showToasts", type: "bool", label: "Notification toasts", hint: "Bottom-right popups" },
                { key: "showTodo", type: "bool", label: "Todo widget", hint: "Floating, bottom-left. Open with: ipc call todo toggle" },
                { key: "showOsd", type: "bool", label: "Volume and brightness OSD", hint: "Right edge" }
            ] }
        ] },
        { id: "widgets", label: "Widgets", glyph: "widgets", title: "Widgets", sub: "Desktop widgets that sit on the wallpaper", sections: [
            { title: "Show", items: [
                { key: "widgetClock", type: "bool", label: "Clock", hint: "Big time and date" },
                { key: "widgetMedia", type: "bool", label: "Now playing", hint: "Album art and controls for the active player" },
                { key: "widgetMediaHideIdle", type: "bool", label: "Hide when nothing plays", hint: "Off shows a music-note skeleton instead" },
                { key: "widgetSysmon", type: "bool", label: "System monitor", hint: "CPU, memory and temperature" },
                { key: "widgetTodo", type: "bool", label: "Todo list", hint: "Your tasks, click to tick" }
            ] },
            { title: "Size", items: [
                { key: "widgetClockSize", type: "enum", label: "Clock size", hint: "Small is a square showing only the time", options: [
                    { v: "small", l: "Small" },
                    { v: "medium", l: "Medium" }
                ] },
                { key: "widgetClockStacked", type: "bool", label: "Clock stacked", hint: "Small clock only. Hours over minutes" },
                { key: "widgetMediaSize", type: "enum", label: "Now playing size", hint: "Small is a square showing only the album art", options: [
                    { v: "small", l: "Small" },
                    { v: "medium", l: "Medium" }
                ] }
            ] },
            { title: "Font", items: [
                { key: "widgetFont", type: "chips", label: "Widget typeface", hint: "SF Pro is the macOS font (install it yourself). Inter is the closest free match", options: win.widgetFontChoices }
            ] },
            { title: "Layout", items: [
                { type: "action", action: "editWidgets", label: "Move widgets", hint: "Drag them where you want, then press Done (or Esc)", button: "Edit" },
                { type: "action", action: "resetWidgets", label: "Reset positions", hint: "Back to the default spots", button: "Reset" }
            ] }
        ] },
        { id: "lock", label: "Lock", glyph: "lock", title: "Lock screen", sub: "Locks on idle, suspend and loginctl lock-session", sections: [
            { title: "Idle", items: [
                { key: "lockOnIdle", type: "bool", label: "Lock when idle", hint: "Caffeine pauses it" },
                { key: "lockIdleMinutes", type: "int", label: "Lock after", hint: "Minutes without input", min: 1, max: 60, step: 1, unit: " min" },
                { key: "lockScreenOff", type: "bool", label: "Turn the screen off", hint: "A little while after locking" },
                { key: "lockScreenOffSeconds", type: "int", label: "Screen off after", hint: "Seconds after locking", min: 10, max: 300, step: 10, unit: " s" }
            ] },
            { title: "Look", items: [
                { key: "lockBlur", type: "bool", label: "Blur the wallpaper" }
            ] },
            { title: "Password", items: [
                { key: "lockPam", type: "text", label: "PAM service", hint: "/etc/pam.d/<name>. On NixOS add security.pam.services.haze = {}; and use haze. Press Enter to apply", placeholder: "login" },
                { type: "action", action: "lockNow", label: "Lock now", hint: "Same as: ipc call lock lock", button: "Lock" }
            ] }
        ] },
        { id: "about", label: "About", glyph: "\uf05a", title: "About", sub: "Where things live and how to control the shell", sections: [
            { title: "Files", items: [
                { type: "info", label: "settings", hint: "~/.config/quickshell/haze-settings.json" },
                { type: "info", label: "colors", hint: "~/.config/quickshell/colors.json (matugen)" }
            ] },
            { title: "IPC  ·  qs -c haze ipc call …", items: [
                { type: "info", label: "launcher toggle | calc | emoji | run", hint: "Apps, calculator, emoji, commands" },
                { type: "info", label: "clipboard toggle", hint: "Clipboard history" },
                { type: "info", label: "wallpaper toggle", hint: "Wallpaper picker" },
                { type: "info", label: "capture toggle | region | window | record", hint: "Screenshots and recording" },
                { type: "info", label: "lock lock", hint: "Lock the session (unlock with your password)" },
                { type: "info", label: "power toggle", hint: "Lock, log out, suspend, reboot, shut down" },
                { type: "info", label: "widgets edit | done", hint: "Move the desktop widgets" },
                { type: "info", label: "todo toggle", hint: "Floating todo list" },
                { type: "info", label: "settings toggle", hint: "This window" }
            ] },
            { title: "Danger zone", items: [
                { type: "action", action: "resetAll", label: "Reset all settings", hint: "Back to the defaults", button: "Reset", danger: true }
            ] }
        ] }
    ]

    property int pageIndex: 0
    readonly property var page: pages[pageIndex]
    readonly property string q: search.text.trim().toLowerCase()
    readonly property bool searching: q !== ""

    readonly property var sections: {
        if (!searching) return page.sections;
        const out = [];
        for (const p of pages) {
            for (const s of p.sections) {
                for (const it of s.items) {
                    if (it.type === "preview" || it.type === "info") continue;
                    const hay = ((it.label ?? "") + " " + (it.hint ?? "") + " " + p.label + " " + s.title).toLowerCase();
                    if (hay.includes(q))
                        out.push(Object.assign({}, it, { hint: (it.hint ? it.hint + "  ·  " : "") + p.label }));
                }
            }
        }
        return out.length > 0 ? [{ title: out.length + (out.length === 1 ? " result" : " results"), items: out }] : [];
    }

    property string armed: ""

    function runAction(id) {
        if (id === "editWidgets") {
            Widgets.edit();
            SettingsUi.hide();
        } else if (id === "resetWidgets") {
            Settings.reset(["widgetClockX", "widgetClockY", "widgetMediaX", "widgetMediaY", "widgetSysmonX", "widgetSysmonY",
                "widgetTodoX", "widgetTodoY"]);
        } else if (id === "lockNow") {
            SettingsUi.hide();
            Lock.lock();
        } else if (id === "reapply") {
            if (Wallpaper.current !== "") Wallpaper.apply(Wallpaper.current);
        } else if (id === "resetAll") {
            if (armed !== id) {
                armed = id;
                armTimer.restart();
                return;
            }
            armed = "";
            Settings.reset(Object.keys(Settings.defaults));
        }
    }

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: win.armed = ""
    }
    Timer {
        id: focusTimer
        interval: 80
        onTriggered: card.forceActiveFocus()
    }

    // page switch: content fades and lifts in
    onPageIndexChanged: swap.restart()
    onSearchingChanged: swap.restart()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    visible: open || card.opacity > 0.01
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "haze-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // dim + click outside to close
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: win.open ? 0.45 : 0
        Behavior on opacity { Anim { duration: 250; curve: Look.standard } }

        MouseArea {
            anchors.fill: parent
            onClicked: SettingsUi.hide()
        }
    }

    // ───────────── the window ─────────────
    FocusScope {
        id: card

        x: win.homeX + win.clampX(win.offX)
        y: win.homeY + win.clampY(win.offY)
        width: Math.min(1000, parent.width - 120)
        height: Math.min(660, parent.height - 120)
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        focus: true

        Behavior on opacity { Anim { duration: 220; curve: Look.standard } }
        Behavior on scale { Anim {} }

        Keys.onPressed: ev => {
            if (ev.key === Qt.Key_Escape) {
                SettingsUi.hide();
            } else if (ev.key === Qt.Key_Slash || (ev.key === Qt.Key_F && (ev.modifiers & Qt.ControlModifier))) {
                search.forceActiveFocus();
            } else if ((ev.modifiers & Qt.AltModifier) && ev.key >= Qt.Key_1 && ev.key < Qt.Key_1 + win.pages.length) {
                win.pageIndex = ev.key - Qt.Key_1;
                search.text = "";
            } else {
                return;
            }
            ev.accepted = true;
        }

        // surface + soft shadow
        Rectangle {
            id: body
            anchors.fill: parent
            radius: 32
            color: Look.surface
            border.width: 1
            border.color: Qt.alpha(Look.outline, 0.7)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.55
                shadowBlur: 1.0
                shadowVerticalOffset: 16
            }
        }

        MouseArea { anchors.fill: parent }   // clicks inside don't reach the scrim

        // ── sidebar ──
        Rectangle {
            id: side
            x: 10
            y: 10
            width: 240
            height: parent.height - 20
            radius: 24
            color: Look.surfaceHi

            // title
            Row {
                x: 20
                y: 22
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: Look.primary

                    InkIcon {
                        anchors.centerIn: parent
                        text: "\uf013"
                        color: Look.primaryFg
                        pixelSize: 16
                        box: 36
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Label {
                        text: "Settings"
                        font.bold: true
                        font.pixelSize: 17
                    }
                    Label {
                        text: "haze"
                        color: Look.fgDim
                        font.pixelSize: 11
                    }
                }
            }

            // drag the title to move the window
            DragHandle {
                x: 0
                y: 0
                width: parent.width
                height: 76
                reference: win.contentItem
                onMoved: (dx, dy) => {
                    if (!win.dragging) {
                        win.dragX = Settings.cfg.settingsX;
                        win.dragY = Settings.cfg.settingsY;
                        win.dragging = true;
                    }
                    win.dragX = win.clampX(win.dragX + dx);
                    win.dragY = win.clampY(win.dragY + dy);
                }
                onDropped: {
                    if (!win.dragging) return;
                    Settings.set("settingsX", win.dragX);
                    Settings.set("settingsY", win.dragY);
                    win.dragging = false;
                }
                onReset: {
                    Settings.set("settingsX", 0);
                    Settings.set("settingsY", 0);
                }
            }

            // search
            Rectangle {
                id: searchBox
                x: 14
                y: 82
                width: parent.width - 28
                height: 42
                radius: 21
                color: Look.surfaceHiest
                border.width: search.activeFocus ? 2 : 0
                border.color: Look.primary

                InkIcon {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf002"
                    color: search.activeFocus ? Look.primary : Look.fgDim
                    pixelSize: 14
                    box: 28
                }

                TextInput {
                    id: search
                    anchors.left: parent.left
                    anchors.leftMargin: 40
                    anchors.right: parent.right
                    anchors.rightMargin: 38
                    anchors.verticalCenter: parent.verticalCenter
                    color: Look.fg
                    selectionColor: Look.primary
                    selectedTextColor: Look.primaryFg
                    font.family: Look.font
                    font.pixelSize: 13
                    clip: true

                    Keys.onEscapePressed: ev => {
                        if (text !== "") text = "";
                        else SettingsUi.hide();
                        card.forceActiveFocus();
                        ev.accepted = true;
                    }
                    Keys.onReturnPressed: card.forceActiveFocus()

                    Label {
                        visible: search.text === ""
                        text: "Search settings"
                        color: Look.fgDim
                    }
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    size: 30
                    glyph: "\uf00d"
                    visible: search.text !== ""
                    onClicked: {
                        search.text = "";
                        card.forceActiveFocus();
                    }
                }
            }

            // navigation
            Item {
                id: nav
                x: 12
                y: 144
                width: parent.width - 24
                height: win.pages.length * 50

                Rectangle {
                    y: win.pageIndex * 50
                    width: parent.width
                    height: 46
                    radius: 23
                    color: Look.secondaryContainer
                    opacity: win.searching ? 0 : 1
                    Behavior on y { Anim {} }
                    Behavior on opacity { Anim { duration: 200; curve: Look.standard } }
                }

                Repeater {
                    model: win.pages

                    Item {
                        id: tab

                        required property var modelData
                        required property int index
                        readonly property bool current: win.pageIndex === index && !win.searching

                        y: index * 50
                        width: nav.width
                        height: 46

                        Rectangle {
                            anchors.fill: parent
                            radius: 23
                            color: Look.fg
                            opacity: tabMouse.containsMouse && !tab.current ? 0.06 : 0
                            Behavior on opacity { Anim { duration: 150; curve: Look.standard } }
                        }

                        Row {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12

                            InkIcon {
                                text: tab.modelData.glyph
                                color: tab.current ? Look.primary : Look.fgDim
                                pixelSize: 15
                                box: 22
                            }
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.label
                                font.bold: tab.current
                                color: tab.current ? Look.fg : Look.fgDim
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                search.text = "";
                                win.pageIndex = tab.index;
                                card.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                text: "Changes save automatically"
                color: Look.fgDim
                font.pixelSize: 11
            }
        }

        // ── content ──
        Item {
            id: content
            x: 266
            y: 0
            width: parent.width - 266
            height: parent.height

            // header
            Column {
                x: 24
                y: 30
                width: parent.width - 100
                spacing: 4

                Label {
                    width: parent.width
                    text: win.searching ? "Search" : win.page.title
                    font.bold: true
                    font.pixelSize: 28
                }
                Label {
                    width: parent.width
                    text: win.searching ? "“" + search.text.trim() + "”" : win.page.sub
                    color: Look.fgDim
                    font.pixelSize: 13
                }
            }

            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: 22
                y: 28
                size: 40
                glyph: "\uf00d"
                onClicked: SettingsUi.hide()
            }

            Flickable {
                id: flick
                x: 0
                y: 108
                width: parent.width
                height: parent.height - 108 - 10
                clip: true
                contentWidth: width
                contentHeight: sectionsCol.height + 28
                boundsBehavior: Flickable.StopAtBounds

                ParallelAnimation {
                    id: swap
                    ScriptAction { script: flick.contentY = 0 }
                    Anim { target: sectionsCol; property: "opacity"; from: 0; to: 1; duration: 260; curve: Look.standard }
                    Anim { target: lift; property: "y"; from: 14; to: 0; duration: 420 }
                }

                Column {
                    id: sectionsCol
                    x: 24
                    width: flick.width - 24 - 22
                    spacing: 24
                    transform: Translate { id: lift }

                    Repeater {
                        model: win.sections

                        Column {
                            id: sec

                            required property var modelData

                            width: sectionsCol.width
                            spacing: 10

                            Label {
                                x: 8
                                visible: text !== ""
                                text: sec.modelData.title.toUpperCase()
                                color: Look.fgDim
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 1.2
                            }

                            Rectangle {
                                width: parent.width
                                height: itemsCol.height
                                radius: 24
                                color: Look.surfaceHi

                                Column {
                                    id: itemsCol
                                    width: parent.width

                                    Repeater {
                                        model: sec.modelData.items

                                        Item {
                                            id: row

                                            required property var modelData
                                            required property int index

                                            readonly property string key: modelData.key ?? ""
                                            readonly property var val: key !== "" ? Settings.cfg[key] : undefined
                                            readonly property var opts: modelData.options ?? []

                                            width: itemsCol.width
                                            height: rowLoader.item ? rowLoader.item.implicitHeight : 66

                                            Rectangle {
                                                visible: row.index > 0
                                                x: 22
                                                width: parent.width - 44
                                                height: 1
                                                color: Qt.alpha(Look.fg, 0.07)
                                            }

                                            Loader {
                                                id: rowLoader
                                                width: parent.width
                                                sourceComponent: {
                                                    switch (row.modelData.type) {
                                                    case "bool": return cBool;
                                                    case "enum": return cEnum;
                                                    case "chips": return cChips;
                                                    case "text": return cText;
                                                    case "action": return cAction;
                                                    case "info": return cInfo;
                                                    case "preview": return cPreview;
                                                    default: return cNum;
                                                    }
                                                }
                                            }

                                            Component {
                                                id: cBool

                                                SettingRow {
                                                    label: row.modelData.label
                                                    hint: row.modelData.hint ?? ""

                                                    Toggle {
                                                        checked: row.val === true
                                                        onToggled: v => Settings.set(row.key, v)
                                                    }
                                                }
                                            }

                                            Component {
                                                id: cEnum

                                                SettingRow {
                                                    label: row.modelData.label
                                                    hint: row.modelData.hint ?? ""

                                                    Segmented {
                                                        options: row.opts
                                                        value: row.val
                                                        onPicked: v => Settings.set(row.key, v)
                                                    }
                                                }
                                            }

                                            Component {
                                                id: cNum

                                                SettingRow {
                                                    label: row.modelData.label
                                                    hint: row.modelData.hint ?? ""

                                                    SettingSlider {
                                                        from: row.modelData.min
                                                        to: row.modelData.max
                                                        step: row.modelData.step ?? 1
                                                        unit: row.modelData.unit ?? ""
                                                        value: row.val ?? row.modelData.min
                                                        onMoved: v => Settings.set(row.key, v)
                                                    }
                                                }
                                            }

                                            Component {
                                                id: cInfo

                                                SettingRow {
                                                    mono: true
                                                    label: row.modelData.label
                                                    hint: row.modelData.hint ?? ""
                                                    implicitHeight: 58
                                                }
                                            }

                                            Component {
                                                id: cAction

                                                SettingRow {
                                                    label: row.modelData.label
                                                    hint: row.modelData.hint ?? ""

                                                    Rectangle {
                                                        readonly property bool armed: win.armed === row.modelData.action
                                                        readonly property bool danger: row.modelData.danger === true

                                                        implicitWidth: Math.max(96, actLabel.implicitWidth + 36)
                                                        implicitHeight: 38
                                                        radius: 19
                                                        color: armed ? Look.error
                                                            : actMouse.containsMouse ? (danger ? Look.error : Look.primary)
                                                            : (danger ? Qt.alpha(Look.error, 0.18) : Look.secondaryContainer)
                                                        scale: actMouse.pressed ? 0.95 : 1
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        Behavior on scale { Anim { duration: Look.dur.fast } }

                                                        Label {
                                                            id: actLabel
                                                            anchors.centerIn: parent
                                                            font.bold: true
                                                            font.pixelSize: 12
                                                            text: row.modelData.action === "reapply" && Wallpaper.applying ? "Applying…"
                                                                : parent.armed ? "Click to confirm" : (row.modelData.button ?? "Run")
                                                            color: parent.armed || (actMouse.containsMouse) ? Look.primaryFg
                                                                : (parent.danger ? Look.error : Look.primary)
                                                        }
                                                        MouseArea {
                                                            id: actMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            onClicked: win.runAction(row.modelData.action)
                                                        }
                                                    }
                                                }
                                            }

                                            Component {
                                                id: cChips

                                                Item {
                                                    implicitHeight: chipCol.height + 40

                                                    Column {
                                                        id: chipCol
                                                        x: 22
                                                        y: 20
                                                        width: parent.width - 44
                                                        spacing: 14

                                                        Column {
                                                            spacing: 3
                                                            Label {
                                                                text: row.modelData.label
                                                                font.bold: true
                                                                font.pixelSize: 14
                                                            }
                                                            Label {
                                                                visible: text !== ""
                                                                text: row.modelData.hint ?? ""
                                                                color: Look.fgDim
                                                                font.pixelSize: 11
                                                            }
                                                        }

                                                        Flow {
                                                            width: parent.width
                                                            spacing: 8

                                                            Repeater {
                                                                model: row.opts

                                                                Rectangle {
                                                                    id: chip

                                                                    required property var modelData
                                                                    readonly property bool current: row.val === modelData.v

                                                                    width: chipLabel.implicitWidth + 30
                                                                    height: 36
                                                                    radius: 18
                                                                    color: current ? Look.primary : (chipMouse.containsMouse ? Look.surfaceHiest : Qt.alpha(Look.fg, 0.07))
                                                                    scale: chipMouse.pressed ? 0.95 : 1
                                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                                    Behavior on scale { Anim { duration: Look.dur.fast } }

                                                                    Label {
                                                                        id: chipLabel
                                                                        anchors.centerIn: parent
                                                                        text: chip.modelData.l
                                                                        font.pixelSize: 12
                                                                        font.bold: chip.current
                                                                        color: chip.current ? Look.primaryFg : Look.fg
                                                                    }
                                                                    MouseArea {
                                                                        id: chipMouse
                                                                        anchors.fill: parent
                                                                        hoverEnabled: true
                                                                        onClicked: Settings.set(row.key, chip.modelData.v)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Component {
                                                id: cText

                                                SettingRow {
                                                    label: row.modelData.label
                                                    hint: row.modelData.hint ?? ""

                                                    Rectangle {
                                                        implicitWidth: 240
                                                        implicitHeight: 38
                                                        radius: 19
                                                        color: Look.surfaceHiest
                                                        border.width: field.activeFocus ? 2 : 0
                                                        border.color: Look.primary

                                                        // click anywhere on the pill to focus the field
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.IBeamCursor
                                                            onClicked: field.forceActiveFocus()
                                                        }

                                                        TextInput {
                                                            id: field
                                                            anchors.left: parent.left
                                                            anchors.leftMargin: 16
                                                            anchors.right: parent.right
                                                            anchors.rightMargin: 16
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            color: Look.fg
                                                            selectionColor: Look.primary
                                                            selectedTextColor: Look.primaryFg
                                                            font.family: Look.font
                                                            font.pixelSize: 13
                                                            clip: true
                                                            text: row.val ?? ""

                                                            // Enter or leaving the field saves, Esc reverts
                                                            onEditingFinished: Settings.set(row.key, text.trim())
                                                            Keys.onEscapePressed: ev => {
                                                                text = row.val ?? "";
                                                                card.forceActiveFocus();
                                                                ev.accepted = true;
                                                            }

                                                            Label {
                                                                visible: field.text === ""
                                                                text: row.modelData.placeholder ?? ""
                                                                color: Look.fgDim
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Component {
                                                id: cPreview

                                                SettingsPreview {}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        visible: win.sections.length === 0
                        width: parent.width
                        topPadding: 60
                        horizontalAlignment: Text.AlignHCenter
                        text: "No settings match “" + search.text.trim() + "”"
                        color: Look.fgDim
                    }
                }

                // slim scrollbar
                Rectangle {
                    visible: flick.contentHeight > flick.height + 2
                    x: flick.width - 12
                    y: 4 + (flick.height - 8 - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
                    width: 4
                    height: Math.max(36, (flick.height - 8) * flick.height / flick.contentHeight)
                    radius: 2
                    color: Qt.alpha(Look.fg, flick.moving ? 0.3 : 0.12)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
    }
}
