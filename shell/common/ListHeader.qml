import QtQuick

// Small caps list title with room for buttons on the right (children go there).
Item {
    id: root

    property string title
    property string note
    default property alias actions: row.data

    implicitHeight: 46
    height: implicitHeight

    Label {
        x: 24
        anchors.verticalCenter: parent.verticalCenter
        text: root.title.toUpperCase()
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1.2
        color: Look.fgDim
    }

    Row {
        id: row
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Label {
            visible: root.note !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.note
            font.pixelSize: 11
            color: Look.fgDim
        }
    }
}
