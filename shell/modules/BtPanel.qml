import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// Settings → Connectivity → Bluetooth: your devices (connect, trust, forget), nearby devices to pair,
// and whether this computer is discoverable.
Item {
    id: root

    readonly property bool watching: SettingsUi.open && visible
    property string openAddr: ""

    implicitHeight: col.height

    onWatchingChanged: Bt.scan(watching)
    Component.onCompleted: if (watching) Bt.scan(true)
    Component.onDestruction: Bt.scan(false)

    Connections {
        target: Bt
        function onEnabledChanged() { if (Bt.enabled && root.watching) Bt.scan(true); }
    }

    Column {
        id: col
        width: parent.width
        spacing: 2

        // ── no adapter / off ──
        Item {
            width: col.width
            height: 104
            visible: !Bt.available || !Bt.enabled

            Column {
                anchors.centerIn: parent
                spacing: 12

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !Bt.available ? "No Bluetooth adapter found" : "Bluetooth is off"
                    color: Look.fgDim
                }
                TextButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Bt.available
                    text: "Turn on"
                    primary: true
                    onClicked: Bt.toggle()
                }
            }
        }

        Column {
            width: col.width
            spacing: 2
            visible: Bt.available && Bt.enabled

            SettingRow {
                width: parent.width
                label: "Discoverable"
                hint: Bt.adapterName !== "" ? "Let nearby devices find this computer as " + Bt.adapterName : "Let nearby devices find this computer"

                Toggle {
                    checked: Bt.discoverable
                    onToggled: v => Bt.setDiscoverable(v)
                }
            }

            // ── my devices ──
            ListHeader {
                width: parent.width
                title: "My devices"
            }

            Label {
                x: 24
                width: parent.width - 48
                visible: Bt.mine.length === 0
                bottomPadding: 10
                text: "No paired devices yet. Pair one from the list below."
                color: Look.fgDim
                font.pixelSize: 12
            }

            Repeater {
                model: Bt.mine

                ConnRow {
                    id: row

                    required property var modelData

                    width: col.width
                    glyph: Bt.glyph(modelData)
                    title: modelData.name
                    subtitle: Bt.detail(modelData)
                    active: modelData.connected
                    expandable: true
                    expanded: root.openAddr === modelData.address
                    onToggled: root.openAddr = expanded ? "" : modelData.address

                    TextButton {
                        text: Bt.busy(row.modelData) ? "…" : row.modelData.connected ? "Disconnect" : "Connect"
                        primary: !row.modelData.connected
                        quiet: row.modelData.connected
                        enabled: !Bt.busy(row.modelData)
                        onClicked: Bt.activate(row.modelData)
                    }

                    drawer: Column {
                        x: 24
                        y: 4
                        width: parent.width - 48
                        spacing: 12

                        KeyValues {
                            width: parent.width
                            items: [
                                { k: "Address", v: row.modelData.address ?? "" },
                                { k: "Type", v: Bt.kind(row.modelData) },
                                { k: "Battery", v: row.modelData.batteryAvailable ? Math.round(row.modelData.battery * 100) + "%" : "" }
                            ]
                        }

                        ToggleRow {
                            width: parent.width
                            label: "Trusted (may connect by itself)"
                            checked: row.modelData.trusted === true
                            onToggled: v => Bt.trust(row.modelData, v)
                        }

                        TextButton {
                            text: "Forget device"
                            danger: true
                            confirm: true
                            onClicked: Bt.forget(row.modelData)
                        }
                    }
                }
            }

            // ── nearby ──
            ListHeader {
                width: parent.width
                title: "Nearby devices"
                note: Bt.scanning ? "Searching…" : ""

                IconButton {
                    glyph: "refresh"
                    size: 32
                    primary: Bt.scanning
                    onClicked: Bt.scan(!Bt.scanning)
                }
            }

            Label {
                x: 24
                width: parent.width - 48
                visible: Bt.nearby.length === 0
                bottomPadding: 10
                text: Bt.scanning ? "Put your device in pairing mode" : "Press refresh to search"
                color: Look.fgDim
                font.pixelSize: 12
            }

            Repeater {
                model: Bt.nearby

                ConnRow {
                    id: nrow

                    required property var modelData

                    width: col.width
                    glyph: Bt.glyph(modelData)
                    title: modelData.name
                    subtitle: Bt.detail(modelData)

                    TextButton {
                        text: Bt.pending === nrow.modelData ? "…" : "Pair"
                        primary: true
                        enabled: Bt.pending === null
                        onClicked: Bt.activate(nrow.modelData)
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }
}
