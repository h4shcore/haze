import QtQuick

// Compact "label ........ switch" row for drawers.
Item {
    id: root

    property string label
    property alias checked: sw.checked
    signal toggled(bool value)

    implicitHeight: 34
    height: implicitHeight

    Label {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.pixelSize: 12
    }
    Toggle {
        id: sw
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        onToggled: v => root.toggled(v)
    }
}
