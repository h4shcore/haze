import QtQuick
import QtQuick.Layouts

// Back button + title (+ optional buttons on the right) for the control center sub-menus.
RowLayout {
    id: root

    property string title
    default property alias extra: right.data
    signal back

    spacing: 8

    IconButton {
        glyph: "\uf104"
        size: 32
        onClicked: root.back()
    }
    Label {
        Layout.fillWidth: true
        text: root.title
        font.bold: true
        font.pixelSize: 15
    }
    RowLayout {
        id: right
        spacing: 4
    }
}
