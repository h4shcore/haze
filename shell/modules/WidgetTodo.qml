import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.common
import qs.services

// Desktop todo list: your tasks as quiet type. Click one to tick it (add tasks with the floating
// widget: ipc call todo toggle).
Item {
    id: root

    implicitWidth: 300
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 2

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.35
            shadowBlur: 0.8
            shadowVerticalOffset: 3
        }

        Label {
            Layout.leftMargin: 4
            Layout.bottomMargin: 8
            text: "TODO" + (Todo.remaining > 0 ? "  ·  " + Todo.remaining + " LEFT" : "")
            font.pixelSize: 13
            font.letterSpacing: 4
            color: Look.fgDim
        }

        Label {
            Layout.leftMargin: 4
            visible: Todo.items.length === 0
            text: "Nothing to do"
            font.pixelSize: 15
            color: Look.fgDim
        }

        Repeater {
            model: Todo.items.slice(0, 7)

            Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool done: !!modelData.done

                Layout.fillWidth: true
                Layout.preferredHeight: 32

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Todo.tick(row.index)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    spacing: 12
                    opacity: row.done ? 0.45 : (mouse.containsMouse ? 1 : 0.92)

                    Rectangle {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        radius: 8
                        color: row.done ? Look.primary : "transparent"
                        border.width: row.done ? 0 : 2
                        border.color: Look.fg
                        Behavior on color { ColorAnimation { duration: 150 } }

                        InkIcon {
                            anchors.centerIn: parent
                            visible: row.done
                            text: "\uf00c"
                            pixelSize: 9
                            box: 12
                            color: Look.primaryFg
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: row.modelData.t
                        font.pixelSize: 16
                        font.strikeout: row.done
                    }
                }
            }
        }

        Label {
            Layout.leftMargin: 4
            Layout.topMargin: 4
            visible: Todo.items.length > 7
            text: "+" + (Todo.items.length - 7) + " more"
            font.pixelSize: 12
            color: Look.fgDim
        }
    }
}
