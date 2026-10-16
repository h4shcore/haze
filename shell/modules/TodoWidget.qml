import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Floating todo list, bottom-left of the focused screen. Not attached to anything and invisible
// until opened:  qs -p shell ipc call todo toggle   (bind it in niri).
// Click a task to tick it · type + Enter to add · Esc or ✕ to close.
PanelWindow {
    id: win

    readonly property bool focusedHere: (Compositor.focusedOutput || screen.name) === screen.name
    property bool latched: false
    readonly property bool open: Todo.open && latched && Settings.cfg.showTodo

    readonly property real rowH: 32
    readonly property int maxRows: 6
    readonly property real listH: Todo.items.length === 0 ? 30 : Math.min(Todo.items.length, maxRows) * rowH

    Connections {
        target: Todo
        function onOpenChanged() {
            if (Todo.open) {
                win.latched = win.focusedHere;
                focusTimer.restart();
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 80
        onTriggered: input.forceActiveFocus()
    }

    // fixed-size surface so the layer never resizes mid-animation; only the card is clickable
    anchors {
        left: true
        bottom: true
    }
    margins {
        left: 20
        bottom: 20
    }
    implicitWidth: 320
    implicitHeight: 330
    visible: open || card.opacity > 0.01
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: card }
    WlrLayershell.namespace: "haze-todo"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    FocusScope {
        id: card

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 8
            rightMargin: 8
            bottomMargin: 8
        }
        height: 14 + 30 + 6 + win.listH + 8 + 34 + 14
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.94
        transform: Translate { y: win.open ? 0 : 14; Behavior on y { Anim {} } }
        transformOrigin: Item.BottomLeft
        focus: true

        Behavior on opacity { Anim { duration: 200; curve: Look.standard } }
        Behavior on scale { Anim {} }
        Behavior on height { Anim { curve: Look.smooth } }

        Keys.onEscapePressed: Todo.hide()

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: Look.surface
            border.width: 1
            border.color: Qt.alpha(Look.outline, 0.7)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.5
                shadowBlur: 0.8
                shadowVerticalOffset: 8
            }
        }

        MouseArea { anchors.fill: parent }

        // ── header ──
        RowLayout {
            x: 18
            y: 14
            width: parent.width - 36
            height: 30
            spacing: 8

            InkIcon {
                text: "\uf00c"
                pixelSize: 13
                box: 22
                color: Look.primary
            }
            Label {
                text: "Todo"
                font.bold: true
                font.pixelSize: 14
            }
            Label {
                text: Todo.items.length === 0 ? "" : Todo.remaining === 0 ? "all done" : Todo.remaining + " left"
                font.pixelSize: 12
                color: Look.fgDim
            }
            Item { Layout.fillWidth: true }
            Label {
                visible: Todo.doneCount > 0
                text: "Clear done"
                font.pixelSize: 11
                color: clearMouse.containsMouse ? Look.fg : Look.fgDim

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Todo.clearDone()
                }
            }
            InkIcon {
                text: "\uf00d"
                pixelSize: 12
                box: 22
                color: closeMouse.containsMouse ? Look.fg : Look.fgDim

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Todo.hide()
                }
            }
        }

        // ── tasks ──
        ListView {
            x: 10
            y: 14 + 30 + 6
            width: parent.width - 20
            height: win.listH
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: Todo.items

            delegate: Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool done: !!modelData.done

                width: ListView.view.width
                height: win.rowH

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    radius: 12
                    color: rm.containsMouse || xm.containsMouse ? Look.surfaceHi : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: rm
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Todo.toggle(row.index)
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 8
                        rightMargin: 6
                    }
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        radius: 9
                        color: row.done ? Look.primary : "transparent"
                        border.width: row.done ? 0 : 2
                        border.color: Look.outline
                        Behavior on color { ColorAnimation { duration: 150 } }

                        InkIcon {
                            anchors.centerIn: parent
                            visible: row.done
                            text: "\uf00c"
                            pixelSize: 10
                            box: 14
                            color: Look.primaryFg
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: row.modelData.t
                        font.pixelSize: 13
                        font.strikeout: row.done
                        color: row.done ? Look.fgDim : Look.fg
                        elide: Text.ElideRight
                    }

                    InkIcon {
                        visible: rm.containsMouse || xm.containsMouse
                        text: "\uf00d"
                        pixelSize: 11
                        box: 18
                        color: Look.fgDim

                        MouseArea {
                            id: xm
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Todo.remove(row.index)
                        }
                    }
                }
            }
        }

        Label {
            x: 20
            y: 14 + 30 + 6
            height: win.listH
            verticalAlignment: Text.AlignVCenter
            visible: Todo.items.length === 0
            text: "Nothing to do"
            font.pixelSize: 12
            color: Look.fgDim
        }

        // ── new task ──
        Rectangle {
            x: 10
            y: 14 + 30 + 6 + win.listH + 8
            width: parent.width - 20
            height: 34
            radius: 17
            color: Look.surfaceHi
            border.width: input.activeFocus ? 2 : 0
            border.color: Look.primary

            Label {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "+"
                font.pixelSize: 16
                color: Look.fgDim
            }
            Label {
                x: 34
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: "Add a task"
                font.pixelSize: 13
                color: Look.fgDim
            }

            TextInput {
                id: input
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 34
                    rightMargin: 14
                }
                clip: true
                color: Look.fg
                selectionColor: Look.primary
                selectedTextColor: Look.primaryFg
                selectByMouse: true
                font.family: Look.font
                font.pixelSize: 13

                onAccepted: {
                    Todo.add(text);
                    text = "";
                }
            }
        }
    }
}
