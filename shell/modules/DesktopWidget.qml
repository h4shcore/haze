import QtQuick
import qs.common
import qs.services

// Frame for one desktop widget: position saved in settings, draggable in edit mode with snapping.
//   name: "Clock" -> settings keys widgetClock (on/off), widgetClockX / widgetClockY (-1 = default spot)
// While you drag, the widget follows the pointer and a ghost outline shows where it will land;
// on release it springs onto the grid (or onto a screen edge margin / the center when close).
Item {
    id: root

    required property string name
    required property Item surface            // the window's contentItem (bounds + drag coordinates)
    property real defaultX: 80
    property real defaultY: 120
    property bool showWhen: true
    default property alias content: holder.data

    readonly property bool wanted: Settings.cfg["widget" + name] ?? false
    visible: wanted && (showWhen || Widgets.editing)

    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    readonly property real savedX: Settings.cfg["widget" + name + "X"] ?? -1
    readonly property real savedY: Settings.cfg["widget" + name + "Y"] ?? -1

    function clamp(v, size, extent) {
        const g = Widgets.grid;
        return Math.max(g, Math.min(Math.max(g, extent - size - g), v));
    }

    // nearest grid line, unless the right/bottom margin or the center is closer than 14px
    function snap(v, size, extent) {
        const g = Widgets.grid;
        let best = Math.round(v / g) * g;
        for (const c of [extent - size - g, (extent - size) / 2])
            if (Math.abs(c - v) < 14) best = c;
        return Math.round(clamp(best, size, extent));
    }

    x: clamp(dragging ? dragX : savedX >= 0 ? savedX : defaultX, width, surface.width)
    y: clamp(dragging ? dragY : savedY >= 0 ? savedY : defaultY, height, surface.height)

    // glide onto the snap point after a drop (not while the pointer is carrying it)
    Behavior on x { enabled: !root.dragging; Anim { duration: Look.dur.slow } }
    Behavior on y { enabled: !root.dragging; Anim { duration: Look.dur.slow } }

    // appear: fade + settle
    opacity: visible ? 1 : 0
    scale: visible ? (dragging ? 1.02 : 1) : 0.96
    Behavior on opacity { Anim { duration: 250; curve: Look.standard } }
    Behavior on scale { Anim { duration: Look.dur.fast } }

    Item {
        id: holder
        anchors.fill: parent
    }

    // where it will land
    Rectangle {
        visible: root.dragging
        x: root.snap(root.x, root.width, root.surface.width) - root.x - 6
        y: root.snap(root.y, root.height, root.surface.height) - root.y - 6
        width: root.width + 12
        height: root.height + 12
        radius: 28
        color: Qt.alpha(Look.primary, 0.1)
        border.width: 2
        border.color: Look.primary
    }

    // idle outline in edit mode
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        visible: Widgets.editing && !root.dragging
        radius: 28
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Look.fg, 0.35)
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
            root.dragX = root.clamp(root.dragX + dx, root.width, root.surface.width);
            root.dragY = root.clamp(root.dragY + dy, root.height, root.surface.height);
        }
        onDropped: {
            if (!root.dragging) return;
            Settings.set("widget" + root.name + "X", root.snap(root.dragX, root.width, root.surface.width));
            Settings.set("widget" + root.name + "Y", root.snap(root.dragY, root.height, root.surface.height));
            root.dragging = false;
        }
        onReset: {
            Settings.set("widget" + root.name + "X", -1);
            Settings.set("widget" + root.name + "Y", -1);
        }
    }
}
