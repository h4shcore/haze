import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.common
import qs.services

// Todo list attached to the bottom-left corner of the screen border.
// Hidden until the cursor touches the bottom-left corner (Bar sets `edgeHover`), then it slides up.
// Click a task to tick it, type in the input to add one. Concave ears blend it into the bottom + left borders.
Item {
    id: root

    required property real screenWidth
    required property real screenHeight

    readonly property real e: Look.earRadius
    readonly property real t: Look.border
    readonly property real r: 18
    readonly property real rowH: 32
    readonly property int maxRows: 6

    property bool edgeHover: false    // set by the hot corner in Bar.qml
    property bool expanded: false
    readonly property bool typing: input.activeFocus

    // ── geometry ──
    readonly property real headH: Look.pillHeight - t
    readonly property real listH: Todo.items.length === 0 ? 30 : Math.min(Todo.items.length, maxRows) * rowH
    readonly property real bodyW: 300 + t
    property real bodyH: headH + 4 + listH + 8 + 34 + 10 + t
    property real slide: expanded ? 0 : bodyH + 10

    Behavior on bodyH { Anim {} }
    Behavior on slide { Anim { duration: Look.dur.slow; curve: root.expanded ? Look.smooth : Look.emphasized } }

    width: bodyW
    height: bodyH
    x: 0
    y: screenHeight - height + slide

    Timer {
        id: collapse
        interval: 300
        onTriggered: if (!input.activeFocus) root.expanded = false
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                collapse.stop();
                root.expanded = true;
            } else {
                collapse.restart();
            }
        }
    }

    onEdgeHoverChanged: {
        if (edgeHover) {
            collapse.stop();
            expanded = true;
        } else if (!hover.hovered) {
            collapse.restart();
        }
    }

    onTypingChanged: if (!typing && !hover.hovered) collapse.restart()

    // ── body shape (WsDock's, flipped vertically) ──
    Shape {
        y: -root.e
        width: root.width + root.e
        height: root.height + root.e
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: sp

            readonly property real e: root.e
            readonly property real t: root.t
            readonly property real r: root.r
            readonly property real w: root.width
            readonly property real h: Math.max(root.height, root.t + root.e + root.r)

            fillColor: Look.surface
            strokeWidth: -1

            // shape-local: root-local + (0, e)
            startX: 0
            startY: sp.h + sp.e
            PathLine { x: sp.w + sp.e; y: sp.h + sp.e }
            PathLine { x: sp.w + sp.e; y: sp.h + sp.e - sp.t }
            PathArc { x: sp.w; y: sp.h - sp.t; radiusX: sp.e; radiusY: sp.e; direction: PathArc.Clockwise }
            PathLine { x: sp.w; y: sp.e + sp.r }
            PathArc { x: sp.w - sp.r; y: sp.e; radiusX: sp.r; radiusY: sp.r; direction: PathArc.Counterclockwise }
            PathLine { x: sp.t + sp.e; y: sp.e }
            PathArc { x: sp.t; y: 0; radiusX: sp.e; radiusY: sp.e; direction: PathArc.Clockwise }
            PathLine { x: 0; y: 0 }
            PathLine { x: 0; y: sp.h + sp.e }
        }
    }

    // ── content ──
    Item {
        x: root.t
        width: root.width - root.t
        height: root.height
        clip: true

        RowLayout {
            id: head
            x: Look.pad
            width: parent.width - Look.pad * 2
            height: root.headH
            spacing: 8

            InkIcon {
                text: "\uf00c"
                pixelSize: 13
                box: 20
                color: Look.primary
            }
            Label {
                font.bold: true
                font.pixelSize: 13
                text: Todo.items.length === 0 ? "Todo" : Todo.remaining === 0 ? "All done" : Todo.remaining + " left"
            }
            Item { Layout.fillWidth: true }
            Label {
                visible: root.expanded && Todo.doneCount > 0
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
        }

        // tasks
        ListView {
            id: list
            x: 10
            y: root.headH + 4
            width: parent.width - 20
            height: root.listH
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: Todo.items
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { Anim { duration: 200; curve: Look.standard } }

            delegate: Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool done: !!modelData.done

                width: ListView.view.width
                height: root.rowH

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
            x: 18
            y: root.headH + 4
            height: root.listH
            verticalAlignment: Text.AlignVCenter
            visible: Todo.items.length === 0
            opacity: root.expanded ? 1 : 0
            text: "Nothing to do"
            font.pixelSize: 12
            color: Look.fgDim
            Behavior on opacity { Anim { duration: 200; curve: Look.standard } }
        }

        // new task
        Rectangle {
            x: 10
            y: root.headH + 4 + root.listH + 8
            width: parent.width - 20
            height: 34
            radius: 17
            color: Look.surfaceHi
            border.width: input.activeFocus ? 2 : 0
            border.color: Look.primary
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { Anim { duration: 200; curve: Look.standard } }

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
                enabled: root.expanded
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
                Keys.onEscapePressed: {
                    focus = false;
                    root.expanded = false;
                }
            }
        }
    }
}
