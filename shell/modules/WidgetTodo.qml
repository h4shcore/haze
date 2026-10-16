import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// Todo widget (large): your tasks, click one to tick it. Add tasks with the floating widget
// (haze ipc call todo toggle) — desktop widgets can't take keyboard input.
Item {
    id: root

    readonly property int maxRows: 8

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8

            Label {
                text: "Todo"
                font.pixelSize: 18
                font.weight: Font.Medium
            }
            Item { Layout.fillWidth: true }
            Label {
                visible: Todo.items.length > 0
                text: Todo.remaining === 0 ? "All done" : Todo.remaining + " left"
                font.pixelSize: 12
                color: Todo.remaining === 0 ? Look.primary : Look.fgDim
            }
        }

        Label {
            Layout.topMargin: 6
            visible: Todo.items.length === 0
            text: "Nothing to do"
            font.pixelSize: 14
            color: Look.fgDim
        }

        Repeater {
            model: Todo.items.slice(0, root.maxRows)

            Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool done: !!modelData.done

                Layout.fillWidth: true
                Layout.preferredHeight: 33

                // hairline between rows
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Look.fg, 0.07)
                    visible: row.index < Math.min(Todo.items.length, root.maxRows) - 1
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Todo.tick(row.index)
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 12
                    opacity: row.done ? 0.45 : (mouse.containsMouse ? 1 : 0.92)

                    Rectangle {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        radius: 8
                        color: row.done ? Look.primary : "transparent"
                        border.width: row.done ? 0 : 2
                        border.color: Look.fgDim
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
                        font.pixelSize: 14
                        font.strikeout: row.done
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Label {
            visible: Todo.items.length > root.maxRows
            text: "+" + (Todo.items.length - root.maxRows) + " more"
            font.pixelSize: 12
            color: Look.fgDim
        }
    }
}
