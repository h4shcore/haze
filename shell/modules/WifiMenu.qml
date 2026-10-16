import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// Wi-Fi sub-menu of the control center: scan list, connect, disconnect, password prompt.
Item {
    id: root

    property bool active: false
    property string pwFor: ""
    readonly property bool asking: pwFor !== ""
    signal back

    opacity: active ? 1 : 0
    visible: opacity > 0
    enabled: active
    Behavior on opacity { Anim { duration: 180; curve: Look.standard } }

    onActiveChanged: {
        pwFor = "";
        pw.text = "";
        if (active) {
            Network.error = "";
            Network.scan();
        }
    }
    onAskingChanged: if (asking) focusTimer.restart()

    Timer {
        id: focusTimer
        interval: 120
        onTriggered: pw.forceActiveFocus()
    }

    function pick(n) {
        Network.error = "";
        if (n.active) Network.disconnect(n.ssid);
        else if (n.secure && !n.known) {
            pw.text = "";
            pwFor = n.ssid;
        } else Network.connect(n.ssid, "");
    }

    function cancelPw() {
        pw.text = "";
        pwFor = "";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        MenuHeader {
            Layout.fillWidth: true
            title: "Wi-Fi"
            onBack: root.asking ? root.cancelPw() : root.back()

            IconButton {
                glyph: "refresh"
                size: 32
                enabled: Network.enabled
                onClicked: Network.scan()
            }
            IconButton {
                glyph: "\uf1eb"
                size: 32
                primary: Network.enabled
                onClicked: Network.toggle()
            }
        }

        // password prompt
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: root.asking
            radius: 20
            color: Look.surfaceHi
            border.width: pw.activeFocus ? 2 : 0
            border.color: Look.primary

            Label {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: pw.text === ""
                text: "Password for " + root.pwFor
                font.pixelSize: 13
                color: Look.fgDim
                width: parent.width - 60
            }

            TextInput {
                id: pw
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 16
                    rightMargin: 48
                }
                echoMode: TextInput.Password
                clip: true
                color: Look.fg
                selectionColor: Look.primary
                selectedTextColor: Look.primaryFg
                font.family: Look.font
                font.pixelSize: 13

                onAccepted: {
                    if (text === "") return;
                    Network.connect(root.pwFor, text);
                    root.cancelPw();
                }
                Keys.onEscapePressed: root.cancelPw()
            }

            IconButton {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\uf00c"
                size: 32
                primary: pw.text !== ""
                onClicked: pw.accepted()
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Network.enabled || (Network.networks.length === 0 && !root.asking)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: !Network.enabled ? "Wi-Fi is off" : "No networks found"
            color: Look.fgDim
            font.pixelSize: 13
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Network.enabled && Network.networks.length > 0
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: Network.networks

            delegate: MenuRow {
                required property var modelData

                width: ListView.view.width
                glyph: "\uf1eb"
                glyphOpacity: 0.4 + 0.6 * modelData.signal / 100
                title: modelData.ssid
                subtitle: Network.connecting === modelData.ssid ? "Connecting…"
                    : modelData.active ? "Connected"
                    : modelData.known ? "Saved"
                    : modelData.secure ? "Secured" : "Open"
                trailing: modelData.secure ? "lock" : ""
                selected: modelData.active
                onClicked: root.pick(modelData)
            }
        }

        Label {
            Layout.fillWidth: true
            visible: Network.error !== ""
            text: Network.error
            font.pixelSize: 11
            color: Look.error
        }
    }
}
