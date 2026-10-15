import QtQuick
import QtQuick.Layouts

// One row of a settings card: title + hint on the left, the control (child item) on the right.
Item {
    id: root

    property string label
    property string hint
    property bool mono: false
    default property alias control: slot.data

    implicitHeight: Math.max(66, labels.implicitHeight + 30)

    ColumnLayout {
        id: labels
        x: 22
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(80, root.width - slot.width - 64)
        spacing: 3

        Label {
            Layout.fillWidth: true
            text: root.label
            font.bold: !root.mono
            font.pixelSize: root.mono ? 12 : 14
            color: root.mono ? Look.primary : Look.fg
        }
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.hint
            color: Look.fgDim
            font.pixelSize: 11
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
