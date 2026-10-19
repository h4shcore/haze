import QtQuick
import QtQuick.Layouts

// One entry of a Settings connectivity list (network, device, VPN profile).
// Children become buttons on the right; `drawer` is the part that slides open under the row.
// Clicking the row (or the chevron) emits `toggled` when `expandable`, else `clicked`.
Item {
    id: root

    property string glyph
    property real glyphOpacity: 1
    property string title
    property string subtitle
    property bool active: false
    property bool expandable: false
    property bool expanded: false
    signal clicked
    signal toggled

    default property alias actions: actionRow.data
    property alias drawer: drawerBox.data

    readonly property int headHeight: 58

    implicitHeight: headHeight + drawerH
    height: implicitHeight

    Rectangle {
        x: 10
        y: 2
        width: parent.width - 20
        height: root.headHeight - 4
        radius: 18
        color: root.active ? Qt.alpha(Look.primary, 0.16)
            : headMouse.containsMouse ? Qt.alpha(Look.fg, 0.05) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: headMouse
        x: 10
        y: 2
        width: parent.width - 20
        height: root.headHeight - 4
        hoverEnabled: true
        onClicked: root.expandable ? root.toggled() : root.clicked()
    }

    RowLayout {
        x: 24
        y: 2
        width: parent.width - 48
        height: root.headHeight - 4
        spacing: 12

        InkIcon {
            text: root.glyph
            pixelSize: 17
            box: 26
            opacity: root.glyphOpacity
            color: root.active ? Look.primary : Look.fg
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Label {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: 13
                font.bold: root.active
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                font.pixelSize: 11
                color: Look.fgDim
            }
        }

        Row {
            id: actionRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
        }

        IconButton {
            visible: root.expandable
            glyph: "expand_more"
            size: 32
            rotation: root.expanded ? 180 : 0
            Behavior on rotation { Anim { duration: 220; curve: Look.standard } }
            onClicked: root.toggled()
        }
    }

    // The drawer is one item (a Column). Its wanted height is measured from that item alone and animated
    // separately, so the animated height never feeds back into the measurement.
    readonly property Item drawerItem: drawerBox.children.length > 0 ? drawerBox.children[0] : null
    readonly property real drawerWanted: expanded && drawerItem ? drawerItem.y + drawerItem.height + 14 : 0
    property real drawerH: drawerWanted
    Behavior on drawerH { Anim { duration: 260; curve: Look.standard } }

    Item {
        id: drawerBox
        y: root.headHeight
        width: parent.width
        height: root.drawerH
        opacity: root.expanded ? 1 : 0
        visible: height > 0
        clip: true
        Behavior on opacity { Anim { duration: 200; curve: Look.standard } }
    }
}
