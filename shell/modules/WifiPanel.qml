import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// Settings → Connectivity → Wi-Fi: networks with signal / band / speed, connect + password prompt,
// per-network details (IP, gateway, DNS), auto-connect, forget, hidden networks and saved profiles.
Item {
    id: root

    readonly property bool watching: SettingsUi.open && visible
    property string openSsid: ""     // network whose drawer is open
    property string pwFor: ""        // network we are asking a password for
    property bool hiddenOpen: false
    property bool showAll: false
    readonly property int limit: 6

    // display order as plain names; rows look their live data up, so refreshes don't rebuild them
    property var order: []
    property var savedOrder: []

    implicitHeight: col.height

    function sync() {
        if (pwFor !== "") return;    // never rebuild rows while a password is being typed
        const names = Network.networks.map(n => n.ssid);
        const want = showAll ? names : names.slice(0, limit);
        if (JSON.stringify(want) !== JSON.stringify(order)) order = want;
        const sv = Network.saved.slice();
        if (JSON.stringify(sv) !== JSON.stringify(savedOrder)) savedOrder = sv;
    }

    function toggleOpen(ssid) {
        openSsid = openSsid === ssid ? "" : ssid;
        pwFor = "";
    }

    function join(n) {
        Network.error = "";
        if (n.secure && !n.known) {
            openSsid = n.ssid;
            pwFor = n.ssid;
        } else Network.connect(n.ssid, "");
    }

    function joinHidden() {
        if (hiddenName.text.trim() === "") return;
        Network.error = "";
        Network.connectHidden(hiddenName.text.trim(), hiddenPw.text);
        hiddenName.text = "";
        hiddenPw.text = "";
        hiddenOpen = false;
    }

    onWatchingChanged: {
        Network.wantDetails = watching;
        if (watching) {
            Network.error = "";
            Network.scan();
        }
    }
    onShowAllChanged: sync()
    onPwForChanged: sync()
    Component.onCompleted: {
        Network.wantDetails = watching;
        if (watching) Network.scan();
        sync();
    }
    Component.onDestruction: Network.wantDetails = false

    Connections {
        target: Network
        function onNetworksChanged() { root.sync(); }
        function onSavedChanged() { root.sync(); }
    }

    Column {
        id: col
        width: parent.width
        spacing: 2

        // ── radio off ──
        Item {
            width: col.width
            height: 104
            visible: !Network.enabled

            Column {
                anchors.centerIn: parent
                spacing: 12

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Wi-Fi is off"
                    color: Look.fgDim
                }
                TextButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Turn on"
                    primary: true
                    onClicked: Network.toggle()
                }
            }
        }

        // ── radio on ──
        Column {
            width: col.width
            spacing: 2
            visible: Network.enabled

            ListHeader {
                width: parent.width
                title: "Available networks"
                note: Network.scanning ? "Scanning…" : ""

                IconButton {
                    glyph: "refresh"
                    size: 32
                    enabled: !Network.scanning
                    onClicked: Network.scan()
                }
            }

            Label {
                x: 24
                width: parent.width - 48
                visible: Network.networks.length === 0
                bottomPadding: 10
                text: Network.scanning ? "Looking for networks…" : "No networks found"
                color: Look.fgDim
                font.pixelSize: 12
            }

            Repeater {
                model: root.order

                ConnRow {
                    id: row

                    required property var modelData
                    readonly property var n: Network.networks.find(x => x.ssid === modelData)
                        ?? ({ ssid: modelData, signal: 0, secure: false, active: false, known: false,
                              security: "", band: "", rate: "", chan: "", bssid: "" })

                    width: col.width
                    glyph: "\uf1eb"
                    glyphOpacity: 0.4 + 0.6 * n.signal / 100
                    title: modelData
                    subtitle: Network.connecting === modelData ? "Connecting…"
                        : [n.active ? "Connected" : n.known ? "Saved" : n.secure ? "Secured" : "Open",
                           n.band, n.signal + "%"].filter(s => s !== "").join(" · ")
                    active: n.active
                    expandable: true
                    expanded: root.openSsid === modelData
                    onToggled: root.toggleOpen(modelData)

                    TextButton {
                        text: row.n.active ? "Disconnect" : "Connect"
                        primary: !row.n.active
                        enabled: Network.connecting === ""
                        onClicked: row.n.active ? Network.disconnect(row.modelData) : root.join(row.n)
                    }

                    drawer: Column {
                        x: 24
                        y: 4
                        width: parent.width - 48
                        spacing: 12

                        KeyValues {
                            width: parent.width
                            items: [
                                { k: "Signal", v: row.n.signal + "%" },
                                { k: "Security", v: row.n.secure ? (row.n.security || "Secured") : "Open" },
                                { k: "Band", v: [row.n.band, row.n.chan !== "" ? "ch " + row.n.chan : ""].filter(s => s !== "").join(" · ") },
                                { k: "Speed", v: row.n.rate },
                                { k: "IP address", v: row.n.active ? Network.info.ip : "" },
                                { k: "Gateway", v: row.n.active ? Network.info.gateway : "" },
                                { k: "DNS", v: row.n.active ? Network.info.dns.join(", ") : "" },
                                { k: "BSSID", v: row.n.bssid }
                            ]
                        }

                        RowLayout {
                            width: parent.width
                            spacing: 8
                            visible: root.pwFor === row.modelData

                            Field {
                                id: pw
                                Layout.fillWidth: true
                                password: true
                                placeholder: "Password for " + row.modelData
                                focusWhen: root.pwFor === row.modelData
                                onAccepted: {
                                    if (text === "") return;
                                    Network.connect(row.modelData, text);
                                    text = "";
                                    root.pwFor = "";
                                }
                                onEscaped: {
                                    text = "";
                                    root.pwFor = "";
                                }
                            }
                            TextButton {
                                text: "Join"
                                primary: true
                                onClicked: pw.accepted()
                            }
                        }

                        ToggleRow {
                            width: parent.width
                            visible: row.n.known
                            label: "Connect automatically"
                            checked: Network.autoMap[row.modelData] === true
                            onToggled: v => Network.setAuto(row.modelData, v)
                        }

                        TextButton {
                            visible: row.n.known
                            text: "Forget network"
                            danger: true
                            confirm: true
                            onClicked: Network.forget(row.modelData)
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 44
                visible: Network.networks.length > root.limit

                TextButton {
                    anchors.centerIn: parent
                    text: root.showAll ? "Show fewer" : "Show " + (Network.networks.length - root.limit) + " more"
                    onClicked: root.showAll = !root.showAll
                }
            }

            // ── hidden network ──
            ConnRow {
                width: col.width
                glyph: "\uf067"
                title: "Join a hidden network"
                subtitle: "For networks that don't broadcast their name"
                expandable: true
                expanded: root.hiddenOpen
                onToggled: root.hiddenOpen = !root.hiddenOpen

                drawer: Column {
                    x: 24
                    y: 4
                    width: parent.width - 48
                    spacing: 10

                    Field {
                        id: hiddenName
                        width: parent.width
                        placeholder: "Network name"
                        focusWhen: root.hiddenOpen
                        onAccepted: hiddenPw.focusInput()
                        onEscaped: root.hiddenOpen = false
                    }
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        Field {
                            id: hiddenPw
                            Layout.fillWidth: true
                            password: true
                            placeholder: "Password (empty for open)"
                            onAccepted: root.joinHidden()
                            onEscaped: root.hiddenOpen = false
                        }
                        TextButton {
                            text: "Join"
                            primary: true
                            enabled: hiddenName.text.trim() !== ""
                            onClicked: root.joinHidden()
                        }
                    }
                }
            }

            // ── saved, out of range ──
            ListHeader {
                width: parent.width
                visible: root.savedOrder.length > 0
                title: "Saved networks"
                note: "Out of range"
            }

            Repeater {
                model: root.savedOrder

                ConnRow {
                    id: srow

                    required property var modelData

                    width: col.width
                    glyph: "\uf1eb"
                    glyphOpacity: 0.4
                    title: modelData
                    subtitle: Network.autoMap[modelData] === true ? "Saved · connects automatically" : "Saved"
                    expandable: true
                    expanded: root.openSsid === "saved:" + modelData
                    onToggled: root.toggleOpen("saved:" + modelData)

                    drawer: Column {
                        x: 24
                        y: 4
                        width: parent.width - 48
                        spacing: 12

                        ToggleRow {
                            width: parent.width
                            label: "Connect automatically"
                            checked: Network.autoMap[srow.modelData] === true
                            onToggled: v => Network.setAuto(srow.modelData, v)
                        }
                        TextButton {
                            text: "Forget network"
                            danger: true
                            confirm: true
                            onClicked: Network.forget(srow.modelData)
                        }
                    }
                }
            }

            Label {
                x: 24
                width: parent.width - 48
                visible: Network.error !== ""
                topPadding: 4
                wrapMode: Text.Wrap
                text: Network.error
                color: Look.error
                font.pixelSize: 11
            }

            Item { width: 1; height: 8 }
        }
    }
}
