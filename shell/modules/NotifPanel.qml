import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services

Item {
    id: root

    property string tab: "new"      // "new" | "history"

    implicitWidth: 360
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: "Notifications"
                font.bold: true
                font.pixelSize: 14
            }
            IconButton {
                size: 32
                glyph: Notifs.dnd ? "\uf1f6" : "\uf0f3"
                primary: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            IconButton {
                size: 32
                glyph: "\uf1f8"
                onClicked: root.tab === "new" ? Notifs.clearAll() : Notifs.clearHistory()
            }
        }

        Segmented {
            Layout.alignment: Qt.AlignHCenter
            segWidth: 110
            options: [{ v: "new", l: "New" }, { v: "history", l: "History" }]
            value: root.tab
            onPicked: v => root.tab = v
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            visible: root.tab === "new" ? Notifs.count === 0 : Notifs.history.length === 0
            text: root.tab === "new" ? "All caught up" : Settings.cfg.notifHistory ? "No history yet" : "History is turned off"
            color: Look.fgDim
        }

        ListView {
            id: lv
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 380)
            visible: root.tab === "new" && Notifs.count > 0
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel { values: [...Notifs.list] }

            delegate: NotifCard {
                required property var modelData
                width: ListView.view.width
                entry: modelData
            }

            remove: Transition {
                ParallelAnimation {
                    Anim { property: "opacity"; to: 0; curve: Look.standard; duration: 200 }
                    Anim { property: "x"; to: 80; curve: Look.standard; duration: 200 }
                }
            }
            displaced: Transition {
                Anim { property: "y" }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 380)
            visible: root.tab === "history" && Notifs.history.length > 0
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel { values: [...Notifs.history] }

            delegate: NotifHistoryCard {
                required property var modelData
                width: ListView.view.width
                item: modelData
            }
        }
    }
}
