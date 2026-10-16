pragma Singleton
import QtQuick
import Quickshell

// Desktop widgets: edit mode (drag them around, they snap to a grid).
// The widgets themselves live in modules/WidgetsLayer.qml.
Singleton {
    property bool editing: false

    // snapping grid in px; widgets also keep this much distance from the screen edges
    readonly property int grid: 40

    function edit() { editing = true; }
    function done() { editing = false; }
    function toggle() { editing = !editing; }
}
