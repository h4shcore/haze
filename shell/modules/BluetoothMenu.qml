import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// Bluetooth sub-menu of the control center: paired + nearby devices, tap to connect / disconnect / pair.
Item {
    id: root

    property bool active: false
    signal back

    opacity: active ? 1 : 0
    visible: opacity > 0
    enabled: active
    Behavior on opacity { Anim { duration: 180; curve: Look.standard } }

    // scan while the menu is open
    onActiveChanged: Bt.scan(active)

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        MenuHeader {
            Layout.fillWidth: true
            title: "Bluetooth"
            onBack: root.back()

            IconButton {
                glyph: "refresh"
                size: 32
                enabled: Bt.enabled
                primary: Bt.scanning
                onClicked: Bt.scan(!Bt.scanning)
            }
            IconButton {
                glyph: "\uf293"
                size: 32
                primary: Bt.enabled
                onClicked: Bt.toggle()
            }
        }

        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Bt.enabled || Bt.list.length === 0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: !Bt.enabled ? "Bluetooth is off" : Bt.scanning ? "Searching…" : "No devices"
            color: Look.fgDim
            font.pixelSize: 13
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Bt.enabled && Bt.list.length > 0
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: Bt.list

            delegate: MenuRow {
                required property var modelData

                width: ListView.view.width
                glyph: Bt.glyph(modelData)
                title: modelData.name
                subtitle: Bt.detail(modelData)
                selected: modelData.connected
                onClicked: Bt.activate(modelData)
            }
        }
    }
}
