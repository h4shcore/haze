import QtQuick
import qs.services

// Audio bars driven by cava (services/Cava.qml). Asks for the data only while it is visible and `active`.
Item {
    id: root

    property bool active: true
    property color color: Look.primary
    property real gap: 3
    readonly property int count: Cava.bars

    property bool held: false
    readonly property bool wanted: visible && active

    function sync() {
        if (wanted && !held) {
            held = true;
            Cava.hold();
        } else if (!wanted && held) {
            held = false;
            Cava.release();
        }
    }

    onWantedChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (held) Cava.release()

    Repeater {
        model: root.count

        Rectangle {
            required property int index

            readonly property real w: (root.width - (root.count - 1) * root.gap) / root.count

            x: index * (w + root.gap)
            width: w
            height: Math.max(w, root.height * (root.active ? (Cava.values[index] ?? 0) : 0))
            y: root.height - height
            radius: w / 2
            color: root.color

            Behavior on height { NumberAnimation { duration: 70 } }
        }
    }
}
