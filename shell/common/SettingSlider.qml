import QtQuick

// Slider with a round thumb and a value pill. Snaps to `step`.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 1
    property string unit: ""
    signal moved(real v)

    readonly property int decimals: step < 1 ? 1 : 0
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    implicitWidth: 290
    implicitHeight: 36

    function snap(x) {
        let v = Math.round((x - from) / step) * step + from;
        v = Math.max(from, Math.min(to, v));
        return Math.round(v * 100) / 100;
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: pill.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Look.surfaceHiest

        Rectangle {
            width: root.frac * parent.width
            height: parent.height
            radius: 3
            color: Look.primary
            Behavior on width {
                enabled: !area.pressed
                Anim { duration: 150; curve: Look.standard }
            }
        }

        Rectangle {
            x: root.frac * parent.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: area.pressed ? 24 : (area.containsMouse ? 22 : 20)
            height: width
            radius: width / 2
            color: Look.primary
            border.width: 4
            border.color: Look.surfaceHi

            Behavior on x {
                enabled: !area.pressed
                Anim { duration: 150; curve: Look.standard }
            }
            Behavior on width { Anim { duration: Look.dur.fast } }
        }
    }

    Rectangle {
        id: pill
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: 28
        radius: 14
        color: Look.surfaceHiest

        Label {
            anchors.centerIn: parent
            text: root.value.toFixed(root.decimals) + root.unit
            font.bold: true
            font.pixelSize: 12
            color: Look.primary
        }
    }

    MouseArea {
        id: area
        x: track.x - 10
        width: track.width + 20
        height: parent.height
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        function update(mx) {
            const f = Math.max(0, Math.min(1, (mx - 10) / track.width));
            root.moved(root.snap(root.from + f * (root.to - root.from)));
        }
        onPressed: m => update(m.x)
        onPositionChanged: m => { if (pressed) update(m.x); }
    }
}
