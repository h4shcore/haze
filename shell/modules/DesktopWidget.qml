import QtQuick
import QtQuick.Effects
import qs.common
import qs.services

// One desktop widget, macOS style: a solid rounded card in a standard size.
//   name: "Clock" -> settings keys widgetClock (on/off), widgetClockX / widgetClockY (-1 = default spot)
//   size: "small" 160×160 · "medium" 340×160 · "large" 340×340
// In edit mode it can be dragged: it follows the pointer, a ghost shows where it will land, and on
// release it glides onto the grid (or the edge margin / center when close).
Item {
    id: root

    required property string name
    required property Item surface            // the window's contentItem (bounds + drag coordinates)
    property string size: "medium"
    property real defaultX: 60
    property real defaultY: 100
    property bool showWhen: true
    default property alias content: holder.data

    readonly property bool wanted: Settings.cfg["widget" + name] ?? false
    visible: wanted && (showWhen || Widgets.editing)

    width: size === "small" ? 160 : 340
    height: size === "large" ? 340 : 160

    property bool dragging: false
    property real dragX: 0
    property real dragY: 0
    readonly property real savedX: Settings.cfg["widget" + name + "X"] ?? -1
    readonly property real savedY: Settings.cfg["widget" + name + "Y"] ?? -1

    function clamp(v, sz, extent) {
        const m = Widgets.margin;
        return Math.max(m, Math.min(Math.max(m, extent - sz - m), v));
    }

    // nearest grid line, unless the far margin or the center is closer than 14px
    function snap(v, sz, extent) {
        const g = Widgets.grid;
        let best = Math.round(v / g) * g;
        for (const c of [extent - sz - Widgets.margin, (extent - sz) / 2])
            if (Math.abs(c - v) < 14) best = c;
        return Math.round(clamp(best, sz, extent));
    }

    x: clamp(dragging ? dragX : savedX >= 0 ? savedX : defaultX, width, surface.width)
    y: clamp(dragging ? dragY : savedY >= 0 ? savedY : defaultY, height, surface.height)

    // glide onto the snap point after a drop (not while the pointer is carrying it)
    Behavior on x { enabled: !root.dragging; Anim { duration: Look.dur.slow } }
    Behavior on y { enabled: !root.dragging; Anim { duration: Look.dur.slow } }

    // appear: fade + settle; lift slightly while dragged
    opacity: visible ? 1 : 0
    scale: visible ? (dragging ? 1.03 : 1) : 0.95
    Behavior on opacity { Anim { duration: 250; curve: Look.standard } }
    Behavior on scale { Anim { duration: Look.dur.fast } }

    // the card
    Rectangle {
        anchors.fill: parent
        radius: 28
        color: Look.surface
        border.width: 1
        border.color: Qt.alpha(Look.outline, 0.5)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: root.dragging ? 0.6 : 0.4
            shadowBlur: 0.8
            shadowVerticalOffset: root.dragging ? 12 : 6
        }
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    // where it will land
    Rectangle {
        visible: root.dragging
        x: root.snap(root.x, root.width, root.surface.width) - root.x - 6
        y: root.snap(root.y, root.height, root.surface.height) - root.y - 6
        z: -1
        width: root.width + 12
        height: root.height + 12
        radius: 34
        color: Qt.alpha(Look.primary, 0.12)
        border.width: 2
        border.color: Look.primary
    }

    // idle outline in edit mode
    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        visible: Widgets.editing && !root.dragging
        radius: 34
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
