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
// Drag the header to move it (double-click the header to put it back).
PanelWindow {
    id: win

    readonly property bool focusedHere: (Compositor.focusedOutput || screen.name) === screen.name
    property bool latched: false
    readonly property bool open: Todo.open && latched && Settings.cfg.showTodo

    // dragging: offsets from the default bottom-left spot, saved on drop
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    readonly property real offX: dragging ? dragX : Settings.cfg.todoX
    readonly property real offY: dragging ? dragY : Settings.cfg.todoY
    readonly property real margin: 28
    readonly property real baseY: height - card.height - margin

    function clampX(v) { return Math.max(80 - card.width - margin, Math.min(width - 80 - margin, v)); }
    function clampY(v) { return Math.max(-baseY, Math.min(height - 60 - baseY, v)); }

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

    // full-screen transparent surface so the card can be dragged anywhere; only the card is clickable
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    visible: open || card.opacity > 0.01
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: card }
    WlrLayershell.namespace: "haze-todo"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    FocusScope {
        id: card

        width: 304
        x: win.margin + win.clampX(win.offX)
        y: win.baseY + win.clampY(win.offY)
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

        // drag the header to move the widget
        DragHandle {
            x: 0
            y: 0
            width: parent.width
            height: 14 + 30 + 6
            reference: win.contentItem
            onMoved: (dx, dy) => {
                if (!win.dragging) {
                    win.dragX = Settings.cfg.todoX;
                    win.dragY = Settings.cfg.todoY;
                    win.dragging = true;
                }
                win.dragX = win.clampX(win.dragX + dx);
                win.dragY = win.clampY(win.dragY + dy);
            }
            onDropped: {
                if (!win.dragging) return;
                Settings.set("todoX", win.dragX);
                Settings.set("todoY", win.dragY);
                win.dragging = false;
            }
            onReset: {
                Settings.set("todoX", 0);
                Settings.set("todoY", 0);
            }
        }

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
                    onClicked: Todo.tick(row.index)
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
