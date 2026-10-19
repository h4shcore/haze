import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// Settings → Connectivity → Ethernet: every wired adapter with link state, live speed, IP details,
// connect / disconnect, auto-connect and DHCP / manual addressing.
Item {
    id: root

    readonly property bool watching: SettingsUi.open && visible
    property string openDev: ""
    property var order: []           // device names; rows look their live data up

    implicitHeight: col.height

    function sync() {
        const want = Ethernet.devices.slice();
        if (JSON.stringify(want) !== JSON.stringify(order)) order = want;
    }

    onWatchingChanged: {
        Ethernet.wantDetails = watching;
        if (watching) Ethernet.refreshAll();
    }
    Component.onCompleted: {
        Ethernet.wantDetails = watching;
        if (watching) Ethernet.refreshAll();
        sync();
    }
    Component.onDestruction: Ethernet.wantDetails = false

    Connections {
        target: Ethernet
        function onDevicesChanged() { root.sync(); }
    }

    Column {
        id: col
        width: parent.width
        spacing: 2

        Label {
            x: 24
            width: parent.width - 48
            visible: root.order.length === 0
            topPadding: 16
            bottomPadding: 18
            text: "No Ethernet adapter found"
            color: Look.fgDim
            font.pixelSize: 12
        }

        Repeater {
            model: root.order

            ConnRow {
                id: row

                required property var modelData
                readonly property var d: Ethernet.get(modelData)
                property string mode: ""     // IP mode picked in the drawer, "" = whatever the profile uses now
                readonly property string curMode: mode !== "" ? mode : (d.method === "manual" ? "manual" : "auto")
                readonly property bool hasProfile: d.connection !== ""

                width: col.width
                glyph: "lan"
                glyphOpacity: d.state === "unavailable" ? 0.4 : 1
                title: modelData + (hasProfile ? "  ·  " + d.connection : "")
                subtitle: d.state === "unavailable" ? "Cable unplugged"
                    : d.state === "connecting" ? "Connecting…"
                    : d.state === "connected"
                        ? ["Connected", d.speed, d.rx > 0 ? "↓ " + Network.fmtRate(d.down) + "  ↑ " + Network.fmtRate(d.up) : ""].filter(s => s !== "").join(" · ")
                    : "Disconnected"
                active: d.state === "connected"
                expandable: true
                expanded: root.openDev === modelData
                onToggled: root.openDev = expanded ? "" : modelData

                TextButton {
                    text: row.d.state === "connected" ? "Disconnect" : "Connect"
                    primary: row.d.state !== "connected"
                    enabled: !Ethernet.busy && row.d.state !== "unavailable"
                    onClicked: row.d.state === "connected" ? Ethernet.disconnect(row.modelData) : Ethernet.connect(row.modelData)
                }

                drawer: Column {
                    x: 24
                    y: 4
                    width: parent.width - 48
                    spacing: 12

                    KeyValues {
                        width: parent.width
                        items: [
                            { k: "Profile", v: row.d.connection },
                            { k: "IP address", v: row.d.ip },
                            { k: "Gateway", v: row.d.gateway },
                            { k: "DNS", v: row.d.dns.join(", ") },
                            { k: "MAC", v: row.d.mac },
                            { k: "Link speed", v: row.d.speed },
                            { k: "Downloaded", v: row.d.rx > 0 ? Network.fmtBytes(row.d.rx) : "" },
                            { k: "Uploaded", v: row.d.rx > 0 ? Network.fmtBytes(row.d.tx) : "" }
                        ]
                    }

                    ToggleRow {
                        width: parent.width
                        visible: row.hasProfile
                        label: "Connect automatically"
                        checked: row.d.auto
                        onToggled: v => Ethernet.setAuto(row.d.connection, v)
                    }

                    Label {
                        visible: row.hasProfile
                        text: "IP ADDRESS"
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1
                        color: Look.fgDim
                    }

                    Segmented {
                        visible: row.hasProfile
                        options: [{ v: "auto", l: "Automatic" }, { v: "manual", l: "Manual" }]
                        value: row.curMode
                        onPicked: v => row.mode = v
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        visible: row.hasProfile && row.curMode === "manual"

                        Field {
                            id: addr
                            width: parent.width
                            placeholder: "Address, like 192.168.1.10/24"
                            Component.onCompleted: text = row.d.ip
                        }
                        Field {
                            id: gw
                            width: parent.width
                            placeholder: "Gateway"
                            Component.onCompleted: text = row.d.gateway
                        }
                        Field {
                            id: dnsField
                            width: parent.width
                            placeholder: "DNS servers, separated by spaces"
                            Component.onCompleted: text = row.d.dns.join(" ")
                        }
                    }

                    TextButton {
                        visible: row.hasProfile && (row.curMode === "manual" || row.d.method === "manual")
                        text: row.curMode === "manual" ? "Apply" : "Switch to automatic"
                        primary: true
                        enabled: !Ethernet.busy
                        onClicked: row.curMode === "manual"
                            ? Ethernet.setManual(row.d.connection, addr.text, gw.text, dnsField.text)
                            : Ethernet.setAutoIp(row.d.connection)
                    }

                    Label {
                        visible: !row.hasProfile && row.d.state !== "unavailable"
                        text: "Connect first to change this adapter's IP settings."
                        color: Look.fgDim
                        font.pixelSize: 11
                    }
                }
            }
        }

        Label {
            x: 24
            width: parent.width - 48
            visible: Ethernet.error !== ""
            topPadding: 4
            wrapMode: Text.Wrap
            text: Ethernet.error
            color: Look.error
            font.pixelSize: 11
        }

        Item { width: 1; height: 8 }
    }
}
