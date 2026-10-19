pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool scanning: adapter?.discovering ?? false
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property string label: !enabled ? "Off"
        : connected.length === 0 ? "On"
        : connected.length === 1 ? connected[0].name + (connected[0].batteryAvailable ? " · " + Math.round(connected[0].battery * 100) + "%" : "")
        : connected.length + " devices"

    // devices for the menu: connected first, then paired, then (while scanning) nearby ones
    readonly property var list: Bluetooth.devices.values
        .filter(d => (d.name ?? "") !== "" && (d.paired || d.connected || scanning))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    function toggle() {
        if (adapter) adapter.enabled = !adapter.enabled;
    }

    function scan(on) {
        if (adapter && adapter.enabled) adapter.discovering = on;
    }

    function busy(d) {
        return d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting;
    }

    function glyph(d) {
        const i = d.icon ?? "";
        if (/head(set|phone)|audio/.test(i)) return "headphones";
        if (i.indexOf("keyboard") >= 0) return "keyboard";
        if (i.indexOf("mouse") >= 0) return "mouse";
        if (i.indexOf("phone") >= 0) return "smartphone";
        if (i.indexOf("computer") >= 0) return "computer";
        if (i.indexOf("gaming") >= 0) return "sports_esports";
        return "\uf293";
    }

    function detail(d) {
        if (busy(d)) return d.state === BluetoothDeviceState.Connecting ? "Connecting…" : "Disconnecting…";
        const bat = d.batteryAvailable ? Math.round(d.battery * 100) + "%" : "";
        if (d.connected) return bat !== "" ? "Connected · " + bat : "Connected";
        return d.paired ? "Paired" : "Available";
    }

    // tap on a device: disconnect / connect / pair-then-connect
    function activate(d) {
        if (busy(d)) return;
        if (d.connected) d.disconnect();
        else if (d.paired) d.connect();
        else {
            pending = d;
            tries = 0;
            d.trusted = true;
            d.pair();
            pairTimer.restart();
        }
    }

    property var pending: null
    property int tries: 0

    // after pairing finishes, connect once (some devices don't auto-connect)
    Timer {
        id: pairTimer
        interval: 900
        repeat: true
        onTriggered: {
            const d = root.pending;
            root.tries++;
            if (!d || root.tries > 20) {
                root.pending = null;
                stop();
            } else if (d.connected) {
                root.pending = null;
                stop();
            } else if (d.paired) {
                d.connect();
                root.pending = null;
                stop();
            }
        }
    }
}
