import QtQuick
import qs.common
import qs.services

// Frame for one desktop widget: position saved in settings, draggable in edit mode.
//   name: "Clock" -> settings keys widgetClock (on/off), widgetClockX / widgetClockY (-1 = default spot)
Item {
    id: root

    required property string name
    required property Item surface            // the window's contentItem (bounds + drag coordinates)
    property real defaultX: 80
    property real defaultY: 80
    property bool showWhen: true
    default property alias content: holder.data

    readonly property bool wanted: Settings.cfg["widget" + name] ?? false
    visible: wanted && (showWhen || Widgets.editing)

    // position: dragging value, else saved value, else default; always kept on screen
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    readonly property real savedX: Settings.cfg["widget" + name + "X"] ?? -1
    readonly property real savedY: Settings.cfg["widget" + name + "Y"] ?? -1

    function clampX(v) { return Math.max(0, Math.min(surface.width - width, v)); }
    function clampY(v) { return Math.max(0, Math.min(surface.height - height, v)); }

    x: clampX(dragging ? dragX : savedX >= 0 ? savedX : defaultX)
    y: clampY(dragging ? dragY : savedY >= 0 ? savedY : defaultY)

    // fade + settle when shown
    opacity: visible ? 1 : 0
    Behavior on opacity { Anim { duration: 250; curve: Look.standard } }

    Item {
        id: holder
        anchors.fill: parent
    }

    // edit mode: dashed-look outline + drag over the whole widget
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        visible: Widgets.editing
        radius: 28
        color: Qt.alpha(Look.primary, 0.1)
        border.width: 2
        border.color: Look.primary
    }

    DragHandle {
        anchors.fill: parent
        visible: Widgets.editing
        reference: root.surface
        onMoved: (dx, dy) => {
            if (!root.dragging) {
                root.dragX = root.x;
                root.dragY = root.y;
                root.dragging = true;
            }
            root.dragX = root.clampX(root.dragX + dx);
            root.dragY = root.clampY(root.dragY + dy);
        }
        onDropped: {
            if (!root.dragging) return;
            Settings.set("widget" + root.name + "X", Math.round(root.dragX));
            Settings.set("widget" + root.name + "Y", Math.round(root.dragY));
            root.dragging = false;
        }
        onReset: {
            Settings.set("widget" + root.name + "X", -1);
            Settings.set("widget" + root.name + "Y", -1);
        }
    }
}
