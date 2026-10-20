import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// The hover-expanded control center, bento style. Default layout:
//   [ Wi-Fi · Bluetooth · Focus · Inbox · Night light ][ vol ][ bri ]
//   [ now-playing card                ]
//   [ shortcut strip                  ]
// Customizable in Settings → Bar & notch: the order of the three cards (ccOrder), which toggles and
// shortcuts show and in what order (ccTiles, ccShortcuts), sizes, spacing, corners, and which side the
// sliders and the system monitor sit on.
// VPN, Wi-Fi, Bluetooth and night light also live in Settings → Connectivity.
// The › on the Wi-Fi / Bluetooth tiles (or right-clicking them / the volume slider) swaps the stack for a sub-menu.
// With the system monitor on, a tall panel sits beside the whole stack.
// `shown` drives the staggered reveal.
Item {
    id: root

    property bool shown: false
    property string page: ""          // "" | "wifi" | "bt" | "audio"
    readonly property bool wantKeys: page === "wifi" && wifiMenu.asking

    // the cards live in Loaders (so they can be reordered); they report their drags up through these
    property bool volDown: false
    property bool briDown: false
    property bool mediaDown: false
    readonly property bool busy: volDown || briDown || mediaDown || wantKeys
    signal openNotifs

    readonly property int gap: Settings.cfg.ccGap
    readonly property bool sysOn: Settings.cfg.ccShowSysMon
    readonly property bool sysLeft: sysOn && Settings.cfg.ccSysMonSide === "left"
    readonly property real sideW: Settings.cfg.ccSysMonWidth
    readonly property real stackX: sysLeft ? sideW + gap : 0     // where the card stack starts

    // ── what to show, from settings (unknown names are ignored, so a hand-edited file can't break it) ──
    readonly property var order: Settings.listOf("ccOrder", ["tiles", "media", "shortcuts"], true)
    readonly property var tileKeys: Settings.listOf("ccTiles", ["wifi", "bt", "focus", "inbox", "night"], false)
        .filter(k => k !== "bt" || Bt.available)
    readonly property var stripKeys: Settings.listOf("ccShortcuts", ["apps", "clip", "wall", "cap", "power", "caf", "pwr", "set"], false)
        .filter(k => k !== "pwr" || PowerProfile.available)

    readonly property var tileMeta: ({
        wifi: { t: "Wi-Fi", g: "\uf1eb" },
        bt: { t: "Bluetooth", g: "\uf293" },
        focus: { t: "Focus", g: "\uf0f3" },
        inbox: { t: "Inbox", g: "\uf086" },
        night: { t: "Night light", g: "nightlight" }
    })

    function stripGlyph(m) {
        switch (m) {
        case "apps": return "\uf009";
        case "clip": return "\uf0ea";
        case "wall": return "\uf03e";
        case "cap": return "\uf030";
        case "power": return "power_settings_new";
        case "caf": return "coffee";
        case "pwr": return PowerProfile.glyph;
        default: return "\uf013";
        }
    }
    readonly property var stripModel: stripKeys.map(m => ({ g: root.stripGlyph(m), m: m }))

    implicitWidth: Settings.cfg.ccWidth + (sysOn ? sideW + gap : 0)
    implicitHeight: page !== "" ? Math.max(col.implicitHeight, 280) : col.implicitHeight

    onShownChanged: if (!shown) page = ""

    ColumnLayout {
        id: col
        x: root.stackX
        width: Settings.cfg.ccWidth
        spacing: root.gap
        opacity: root.page === "" ? 1 : 0
        enabled: root.page === ""
        Behavior on opacity { Anim { duration: 180; curve: Look.standard } }

        Repeater {
            model: root.order

            Loader {
                id: slot

                required property var modelData
                required property int index

                Layout.fillWidth: true
                visible: modelData === "tiles" ? (root.tileKeys.length > 0 || Settings.cfg.ccShowSliders)
                    : modelData === "media" ? (Players.active !== null && Settings.cfg.ccShowMedia)
                    : (Settings.cfg.ccShowShortcuts && root.stripKeys.length > 0)
                sourceComponent: modelData === "tiles" ? tilesCard : modelData === "media" ? mediaCard : stripCard
                onLoaded: if (item) item.delay = slot.index * 50
            }
        }
    }

    // ── toggles + vertical sliders ──
    Component {
        id: tilesCard

        Reveal {
            shown: root.shown

            RowLayout {
                width: parent.width
                height: Settings.cfg.ccTilesHeight
                spacing: root.gap
                layoutDirection: Settings.cfg.ccSlidersSide === "left" ? Qt.RightToLeft : Qt.LeftToRight

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    rowSpacing: root.gap
                    columnSpacing: root.gap

                    Repeater {
                        model: root.tileKeys

                        Tile {
                            id: tile

                            required property var modelData
                            required property int index
                            readonly property string k: modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            // an odd last tile stretches across both columns
                            Layout.columnSpan: index === root.tileKeys.length - 1 && root.tileKeys.length % 2 === 1 ? 2 : 1

                            glyph: k === "focus" ? (Notifs.dnd ? "\uf1f6" : "\uf0f3") : root.tileMeta[k].g
                            title: root.tileMeta[k].t
                            subtitle: k === "wifi" ? (!Network.enabled ? "Off" : (Network.ssid || "Not connected"))
                                : k === "bt" ? Bt.label
                                : k === "focus" ? (Notifs.dnd ? "Muted" : "Off")
                                : k === "inbox" ? (Notifs.count > 0 ? Notifs.count + " new" : "All clear")
                                : (NightLight.active ? Settings.cfg.nightLightTemp + " K" : "Off")
                            on: k === "wifi" ? Network.enabled
                                : k === "bt" ? Bt.enabled
                                : k === "focus" ? Notifs.dnd
                                : k === "inbox" ? Notifs.count > 0
                                : NightLight.active
                            hasMenu: k === "wifi" || k === "bt"
                            onClicked: {
                                if (k === "wifi") Network.toggle();
                                else if (k === "bt") Bt.toggle();
                                else if (k === "focus") Notifs.dnd = !Notifs.dnd;
                                else if (k === "inbox") root.openNotifs();
                                else NightLight.toggle();
                            }
                            onMenuRequested: root.page = k === "wifi" ? "wifi" : "bt"
                        }
                    }
                }

                VSlider {
                    Layout.fillHeight: true
                    visible: Settings.cfg.ccShowSliders
                    glyph: Audio.glyph
                    value: Audio.muted ? 0 : Audio.volume
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                    onMenuRequested: root.page = "audio"
                    onPressedChanged: root.volDown = pressed
                }

                VSlider {
                    Layout.fillHeight: true
                    visible: Settings.cfg.ccShowSliders && Brightness.available
                    glyph: "\uf185"
                    value: Brightness.value
                    onMoved: v => Brightness.set(v)
                    onPressedChanged: root.briDown = pressed
                }
            }
        }
    }

    // ── now playing ──
    Component {
        id: mediaCard

        Reveal {
            shown: root.shown

            MediaCard {
                width: parent.width
                onBusyChanged: root.mediaDown = busy
            }
        }
    }

    // ── shortcuts into the bottom docks ──
    Component {
        id: stripCard

        Reveal {
            shown: root.shown

            Rectangle {
                width: parent.width
                height: Settings.cfg.ccStripHeight
                radius: Math.min(height / 2, Settings.cfg.ccCardRadius + 6)
                color: Look.surfaceHi

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 0

                    Repeater {
                        model: root.stripModel

                        Item {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            IconButton {
                                anchors.centerIn: parent
                                size: Math.min(38, Settings.cfg.ccStripHeight - 8)
                                glyph: parent.modelData.g
                                primary: {
                                    const m = parent.modelData.m;
                                    if (m === "set") return SettingsUi.open;
                                    if (m === "caf") return Caffeine.active;
                                    if (m === "pwr") return PowerProfile.profile !== "balanced";
                                    return LauncherState.open && LauncherState.mode === m;
                                }
                                onClicked: {
                                    const m = parent.modelData.m;
                                    if (m === "set") SettingsUi.toggle();
                                    else if (m === "caf") Caffeine.toggle();
                                    else if (m === "pwr") PowerProfile.cycle();
                                    else LauncherState.toggleMode(m);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── sub-menus (replace the stack) ──
    WifiMenu {
        id: wifiMenu
        x: root.stackX
        width: Settings.cfg.ccWidth
        height: root.implicitHeight
        active: root.page === "wifi"
        onBack: root.page = ""
    }

    BluetoothMenu {
        x: root.stackX
        width: Settings.cfg.ccWidth
        height: root.implicitHeight
        active: root.page === "bt"
        onBack: root.page = ""
    }

    AudioMenu {
        x: root.stackX
        width: Settings.cfg.ccWidth
        height: root.implicitHeight
        active: root.page === "audio"
        onBack: root.page = ""
    }

    // ── system monitor, beside the stack ──
    Reveal {
        x: root.sysLeft ? 0 : Settings.cfg.ccWidth + root.gap
        width: root.sideW
        height: root.implicitHeight
        visible: root.sysOn
        shown: root.shown
        delay: 40

        SysMonCard {
            width: parent.width
            height: parent.height
            shown: root.shown
        }
    }
}
