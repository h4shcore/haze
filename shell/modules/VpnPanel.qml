import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services

// Settings → Connectivity → VPN: every NetworkManager VPN / WireGuard profile (connect, auto-connect, remove),
// Tailscale (connect, exit node, devices) and importing a WireGuard / OpenVPN config file.
Item {
    id: root

    readonly property bool watching: SettingsUi.open && visible
    property string openKey: ""
    property bool importOpen: false
    property string importType: "wireguard"
    property var order: []           // profile names; rows look their live data up

    readonly property var tsi: Vpn.tsInfo
    readonly property bool tsUp: tsi !== null && tsi.state === "Running"

    implicitHeight: col.height

    function sync() {
        const want = Vpn.connections.map(c => c.name);
        if (JSON.stringify(want) !== JSON.stringify(order)) order = want;
    }

    function doImport() {
        const p = importPath.text.trim().replace(/^~(?=$|\/)/, Quickshell.env("HOME"));
        if (p === "") return;
        Vpn.importConfig(importType, p);
        importPath.text = "";
        importOpen = false;
    }

    onWatchingChanged: {
        Vpn.wantDetails = watching;
        if (watching) Vpn.refreshAll();
    }
    Component.onCompleted: {
        Vpn.wantDetails = watching;
        if (watching) Vpn.refreshAll();
        sync();
    }
    Component.onDestruction: Vpn.wantDetails = false

    Connections {
        target: Vpn
        function onConnectionsChanged() { root.sync(); }
    }

    Column {
        id: col
        width: parent.width
        spacing: 2

        ListHeader {
            width: parent.width
            title: "Connections"
            note: Vpn.busy ? "Working…" : ""

            IconButton {
                glyph: "refresh"
                size: 32
                onClicked: Vpn.refreshAll()
            }
        }

        Label {
            x: 24
            width: parent.width - 48
            visible: root.order.length === 0 && root.tsi === null
            bottomPadding: 10
            wrapMode: Text.Wrap
            text: "No VPN found. Import a WireGuard or OpenVPN config below, or install and start Tailscale."
            color: Look.fgDim
            font.pixelSize: 12
        }

        Repeater {
            model: root.order

            ConnRow {
                id: row

                required property var modelData
                readonly property var c: Vpn.connections.find(x => x.name === modelData)
                    ?? ({ name: modelData, type: "VPN", active: false, auto: false })

                width: col.width
                glyph: "vpn_key"
                title: modelData
                subtitle: Vpn.connecting === modelData ? (c.active ? "Disconnecting…" : "Connecting…")
                    : c.active ? "Connected · " + c.type
                    : c.type + (c.auto ? " · connects automatically" : "")
                active: c.active
                expandable: true
                expanded: root.openKey === modelData
                onToggled: root.openKey = expanded ? "" : modelData

                TextButton {
                    text: row.c.active ? "Disconnect" : "Connect"
                    primary: !row.c.active
                    enabled: !Vpn.busy
                    onClicked: row.c.active ? Vpn.disconnect(row.modelData) : Vpn.connect(row.modelData)
                }

                drawer: Column {
                    x: 24
                    y: 4
                    width: parent.width - 48
                    spacing: 12

                    ToggleRow {
                        width: parent.width
                        label: "Connect automatically"
                        checked: row.c.auto
                        onToggled: v => Vpn.setAuto(row.modelData, v)
                    }
                    TextButton {
                        text: "Remove connection"
                        danger: true
                        confirm: true
                        enabled: !Vpn.busy
                        onClicked: Vpn.remove(row.modelData)
                    }
                }
            }
        }

        // ── Tailscale ──
        ConnRow {
            id: ts

            width: col.width
            visible: root.tsi !== null
            glyph: "public"
            title: "Tailscale"
            subtitle: root.tsi === null ? ""
                : Vpn.connecting === "tailscale" ? "Working…"
                : root.tsUp ? "Connected · " + root.tsi.ip + (root.tsi.exitName !== "" ? " · exit node " + root.tsi.exitName : "")
                : root.tsi.state === "NeedsLogin" ? "Needs login: run  tailscale up  once"
                : "Disconnected"
            active: root.tsUp
            expandable: true
            expanded: root.openKey === "tailscale"
            onToggled: root.openKey = expanded ? "" : "tailscale"

            TextButton {
                text: root.tsUp ? "Disconnect" : "Connect"
                primary: !root.tsUp
                enabled: !Vpn.busy && root.tsi !== null && root.tsi.state !== "NeedsLogin"
                onClicked: Vpn.tsSet(!root.tsUp)
            }

            drawer: Column {
                x: 24
                y: 4
                width: parent.width - 48
                spacing: 12

                KeyValues {
                    width: parent.width
                    items: root.tsi === null ? [] : [
                        { k: "Tailnet", v: root.tsi.tailnet },
                        { k: "This device", v: root.tsi.host },
                        { k: "Address", v: root.tsi.ip },
                        { k: "Peers online", v: root.tsi.peers > 0 ? root.tsi.online + " of " + root.tsi.peers : "" }
                    ]
                }

                Label {
                    visible: root.tsUp && root.tsi.exits.length > 0
                    text: "EXIT NODE"
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1
                    color: Look.fgDim
                }

                Flow {
                    width: parent.width
                    spacing: 8
                    visible: root.tsUp && root.tsi.exits.length > 0

                    Repeater {
                        model: root.tsi === null ? [] : [{ name: "None", ip: "", on: root.tsi.exitName === "" }].concat(root.tsi.exits)

                        Rectangle {
                            id: chip

                            required property var modelData

                            width: chipLabel.implicitWidth + 30
                            height: 36
                            radius: 18
                            color: modelData.on ? Look.primary : (chipMouse.containsMouse ? Look.surfaceHiest : Qt.alpha(Look.fg, 0.07))
                            opacity: Vpn.busy ? 0.5 : 1
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Label {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: chip.modelData.name
                                font.pixelSize: 12
                                font.bold: chip.modelData.on
                                color: chip.modelData.on ? Look.primaryFg : Look.fg
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !Vpn.busy
                                onClicked: Vpn.tsExit(chip.modelData.ip)
                            }
                        }
                    }
                }
            }
        }

        // ── import ──
        ConnRow {
            width: col.width
            glyph: "\uf067"
            title: "Import a config"
            subtitle: "WireGuard .conf or OpenVPN .ovpn"
            expandable: true
            expanded: root.importOpen
            onToggled: root.importOpen = !root.importOpen

            drawer: Column {
                x: 24
                y: 4
                width: parent.width - 48
                spacing: 10

                Segmented {
                    options: [{ v: "wireguard", l: "WireGuard" }, { v: "openvpn", l: "OpenVPN" }]
                    value: root.importType
                    onPicked: v => root.importType = v
                }
                RowLayout {
                    width: parent.width
                    spacing: 8

                    Field {
                        id: importPath
                        Layout.fillWidth: true
                        placeholder: "~/Downloads/vpn.conf"
                        focusWhen: root.importOpen
                        onAccepted: root.doImport()
                        onEscaped: root.importOpen = false
                    }
                    TextButton {
                        text: "Import"
                        primary: true
                        enabled: importPath.text.trim() !== "" && !Vpn.busy
                        onClicked: root.doImport()
                    }
                }
            }
        }

        Label {
            x: 24
            width: parent.width - 48
            visible: Vpn.error !== ""
            topPadding: 4
            wrapMode: Text.Wrap
            text: Vpn.error
            color: Look.error
            font.pixelSize: 11
        }

        Item { width: 1; height: 8 }
    }
}
