import QtQuick
import QtQuick.Layouts

// Compact toggle for the control center's quick row: icon over a short label.
Rectangle {
    id: root

    property string glyph
    property string title
    property bool on: false
    signal clicked

    implicitHeight: 64
    radius: 18
    color: on ? Look.primary : mouse.containsMouse ? Look.surfaceHiest : Look.surfaceHi
    opacity: enabled ? 1 : 0.4
    scale: mouse.pressed ? 0.95 : 1

    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on scale { Anim { duration: Look.dur.fast } }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 3

        InkIcon {
            Layout.alignment: Qt.AlignHCenter
            text: root.glyph
            pixelSize: 19
            box: 26
            color: root.on ? Look.primaryFg : Look.fg
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.width - 12
            text: root.title
            font.pixelSize: 11
            font.bold: root.on
            color: root.on ? Look.primaryFg : Look.fgDim
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
