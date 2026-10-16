pragma Singleton
import QtQuick
import Quickshell

// Desktop widgets: edit mode (drag them around). The widgets themselves live in modules/WidgetsLayer.qml.
Singleton {
    property bool editing: false

    function edit() { editing = true; }
    function done() { editing = false; }
    function toggle() { editing = !editing; }
}
