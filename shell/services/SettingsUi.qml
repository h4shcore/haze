pragma Singleton
import QtQuick
import Quickshell

// Open/closed state of the floating Settings window.
Singleton {
    property bool open: false

    function show() {
        LauncherState.hide();
        open = true;
    }
    function hide() { open = false; }
    function toggle() {
        if (open) hide();
        else show();
    }
}
