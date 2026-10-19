import QtQuick

// Small pill button with a text label: tinted (default), filled (primary) or red (danger).
// With `confirm: true` the first click arms it ("Click to confirm"), the second one fires.
Rectangle {
    id: root

    property string text
    property bool primary: false
    property bool danger: false
    property bool quiet: false       // neutral, for buttons that sit on a highlighted (connected) row
    property bool confirm: false
    property bool armed: false
    signal clicked

    implicitWidth: Math.max(76, lbl.implicitWidth + 30)
    implicitHeight: 34
    radius: height / 2
    opacity: enabled ? 1 : 0.45
    scale: mouse.pressed ? 0.95 : 1
    color: armed ? Look.error
        : primary ? Look.primary
        : danger ? Qt.alpha(Look.error, mouse.containsMouse ? 0.32 : 0.16)
        : quiet ? Qt.alpha(Look.fg, mouse.containsMouse ? 0.22 : 0.13)
        : mouse.containsMouse ? Look.surfaceHiest : Look.secondaryContainer
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { Anim { duration: Look.dur.fast } }

    Timer {
        id: armTimer
        interval: 3000
        onTriggered: root.armed = false
    }

    Label {
        id: lbl
        anchors.centerIn: parent
        text: root.armed ? "Click to confirm" : root.text
        font.pixelSize: 12
        font.bold: true
        color: root.armed || root.primary ? Look.primaryFg : root.danger ? Look.error : Look.fg
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (root.confirm && !root.armed) {
                root.armed = true;
                armTimer.restart();
                return;
            }
            root.armed = false;
            root.clicked();
        }
    }
}
