import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// The hover-expanded control center, bento style:
//   [ 2x2 toggle tiles ][ vol ][ bri ]
//   [ night light · VPN · record · color picker ]
//   [ now-playing card                ]
//   [ shortcut strip                  ]
// The › on the Wi-Fi / Bluetooth tiles (or right-clicking them / the volume slider) swaps the stack for a sub-menu.
// With the system monitor on, a tall panel sits to the right of the whole stack.
// `shown` drives the staggered reveal.
Item {
    id: root

    property bool shown: false
    property string page: ""          // "" | "wifi" | "bt" | "audio"
    readonly property bool wantKeys: page === "wifi" && wifiMenu.asking
    readonly property bool busy: vol.pressed || bri.pressed || media.busy || wantKeys
    signal openNotifs

    readonly property bool sysOn: Settings.cfg.ccShowSysMon
    readonly property real sideW: 130

    implicitWidth: Settings.cfg.ccWidth + (sysOn ? sideW + 10 : 0)
    implicitHeight: page !== "" ? Math.max(col.implicitHeight, 280) : col.implicitHeight

    onShownChanged: if (!shown) page = ""

    ColumnLayout {
        id: col
        width: Settings.cfg.ccWidth
        spacing: 10
        opacity: root.page === "" ? 1 : 0
        enabled: root.page === ""
        Behavior on opacity { Anim { duration: 180; curve: Look.standard } }

        // ── toggles + vertical sliders ──
        Reveal {
            Layout.fillWidth: true
            shown: root.shown
            delay: 0

            RowLayout {
                width: parent.width
                height: 170
                spacing: 10

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    Tile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        glyph: "\uf1eb"
                        title: "Wi-Fi"
                        subtitle: !Network.enabled ? "Off" : (Network.ssid || "Not connected")
                        on: Network.enabled
                        hasMenu: true
                        onClicked: Network.toggle()
                        onMenuRequested: root.page = "wifi"
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Bt.available
                        glyph: "\uf293"
                        title: "Bluetooth"
                        subtitle: Bt.label
                        on: Bt.enabled
                        hasMenu: true
                        onClicked: Bt.toggle()
                        onMenuRequested: root.page = "bt"
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        glyph: Notifs.dnd ? "\uf1f6" : "\uf0f3"
                        title: "Focus"
                        subtitle: Notifs.dnd ? "Muted" : "Off"
                        on: Notifs.dnd
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                    Tile {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.columnSpan: Bt.available ? 1 : 2
                        glyph: "\uf086"
                        title: "Inbox"
                        subtitle: Notifs.count > 0 ? Notifs.count + " new" : "All clear"
                        on: Notifs.count > 0
                        onClicked: root.openNotifs()
                    }
                }

                VSlider {
                    id: vol
                    Layout.fillHeight: true
                    glyph: Audio.glyph
                    value: Audio.muted ? 0 : Audio.volume
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                    onMenuRequested: root.page = "audio"
                }

                VSlider {
                    id: bri
                    Layout.fillHeight: true
                    visible: Brightness.available
                    glyph: "\uf185"
                    value: Brightness.value
                    onMoved: v => Brightness.set(v)
                }
            }
        }

        // ── quick toggles: night light, VPN, screen recording, color picker ──
        Reveal {
            Layout.fillWidth: true
            visible: Settings.cfg.ccShowQuick
            shown: root.shown
            delay: 25

            RowLayout {
                width: parent.width
                height: 64
                spacing: 10

                MiniTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    glyph: "nightlight"
                    title: "Night light"
                    on: NightLight.active
                    onClicked: NightLight.toggle()
                }
                MiniTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: Vpn.available
                    glyph: "vpn_key"
                    title: Vpn.label
                    on: Vpn.active
                    enabled: !Vpn.busy
                    onClicked: Vpn.toggle()
                }
                MiniTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: Capture.hasRec
                    glyph: Capture.recording ? "\uf04d" : "\uf111"
                    title: Capture.recording ? Capture.fmt(Capture.elapsed) : "Record"
                    on: Capture.recording
                    onClicked: {
                        if (Capture.recording) Capture.stop();
                        else Capture.start("record", Capture.target);
                    }
                }
                MiniTile {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    glyph: "colorize"
                    title: "Pick color"
                    on: ColorPicker.picking
                    onClicked: ColorPicker.pick()
                }
            }
        }

        // ── now playing ──
        Reveal {
            Layout.fillWidth: true
            visible: Players.active !== null && Settings.cfg.ccShowMedia
            shown: root.shown
            delay: 50

            MediaCard {
                id: media
                width: parent.width
            }
        }

        // ── shortcuts into the bottom docks ──
        Reveal {
            Layout.fillWidth: true
            visible: Settings.cfg.ccShowShortcuts
            shown: root.shown
            delay: 100

            Rectangle {
                width: parent.width
                height: 48
                radius: 24
                color: Look.surfaceHi

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    spacing: 0

                    Repeater {
                        model: [
                            { g: "\uf009", m: "apps" },
                            { g: "\uf0ea", m: "clip" },
                            { g: "\uf03e", m: "wall" },
                            { g: "\uf030", m: "cap" },
                            { g: "power_settings_new", m: "power" },
                            { g: "coffee", m: "caf" },
                            ...(PowerProfile.available ? [{ g: PowerProfile.glyph, m: "pwr" }] : []),
                            { g: "\uf013", m: "set" }
                        ]

                        Item {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            IconButton {
                                anchors.centerIn: parent
                                size: 38
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
        width: Settings.cfg.ccWidth
        height: root.implicitHeight
        active: root.page === "wifi"
        onBack: root.page = ""
    }

    BluetoothMenu {
        width: Settings.cfg.ccWidth
        height: root.implicitHeight
        active: root.page === "bt"
        onBack: root.page = ""
    }

    AudioMenu {
        width: Settings.cfg.ccWidth
        height: root.implicitHeight
        active: root.page === "audio"
        onBack: root.page = ""
    }

    // ── system monitor, right side ──
    Reveal {
        x: Settings.cfg.ccWidth + 10
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
