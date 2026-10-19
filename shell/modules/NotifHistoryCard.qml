import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.services

// One saved notification from Notifs.history (no actions: the app that sent it is gone).
Rectangle {
    id: root

    required property var item
    readonly property string src: (item.icon ?? "") === "" ? ""
        : item.icon.startsWith("/") ? "file://" + item.icon : Quickshell.iconPath(item.icon, true)

    function ago(t) {
        const m = Math.floor((Date.now() - t) / 60000);
        if (m < 1) return "now";
        if (m < 60) return m + " min ago";
        const h = Math.floor(m / 60);
        if (h < 24) return h + " h ago";
        return Qt.formatDateTime(new Date(t), "ddd d MMM, HH:mm");
    }

    implicitHeight: col.implicitHeight + 24
    radius: 20
    color: Look.surfaceHi
    border.width: item.urgency === 2 ? 1 : 0
    border.color: Look.error

    RowLayout {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 12

        ClippingRectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignTop
            radius: 11
            color: Look.surfaceHiest

            Image {
                id: img
                anchors.fill: parent
                source: root.src
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            InkIcon {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                text: "\uf0f3"
                pixelSize: 15
                box: 26
                color: Look.fgDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                Layout.fillWidth: true
                text: root.item.app + (root.item.app !== "" ? "  ·  " : "") + root.ago(root.item.time)
                color: Look.fgDim
                font.pixelSize: 11
            }
            Label {
                Layout.fillWidth: true
                text: root.item.summary
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.item.body
                textFormat: Text.StyledText
                color: Look.fgDim
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
        }

        IconButton {
            Layout.alignment: Qt.AlignTop
            size: 28
            glyph: "\uf00d"
            onClicked: Notifs.removeHistory(root.item.id)
        }
    }
}
