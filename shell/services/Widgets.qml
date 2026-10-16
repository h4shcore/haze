pragma Singleton
import QtQuick
import Quickshell

// Desktop widgets: edit mode (drag them around, they snap to a grid).
// The widgets themselves live in modules/WidgetsLayer.qml.
//
// Sizes follow macOS: small 160×160, medium 340×160 (two smalls + the gap), large 340×340.
// The grid equals the gap, so snapped widgets tile neatly.
Singleton {
    property bool editing: false

    readonly property int grid: 20      // snapping grid, px (also the gap between widgets)
    readonly property int margin: 40    // minimum distance from the screen edges

    function edit() { editing = true; }
    function done() { editing = false; }
    function toggle() { editing = !editing; }
}
