import QtQuick

// Vertical pill slider for the control center: fills from the bottom,
// the icon sits at the bottom of the pill (tap it for `iconClicked`).
Item {
    id: root

    property string glyph
    property real value: 0
    property color fill: Look.primary
    readonly property bool pressed: area.pressed
    signal moved(real value)
    signal iconClicked

    implicitWidth: 52
    implicitHeight: 160

    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Look.surfaceHiest

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(parent.width, parent.height * root.clamp(root.value))
            radius: width / 2
            color: root.fill

            Behavior on height {
                enabled: !area.pressed
                Anim { duration: 150; curve: Look.standard }
            }
        }
    }

    InkIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.glyph
        pixelSize: 18
        box: root.width
        color: Look.primaryFg
    }

    // drag / tap anywhere on the pill to set the value
    MouseArea {
        id: area
        anchors.fill: parent
        preventStealing: true
        function update(my) { root.moved(root.clamp(1 - my / height)); }
        onPressed: m => update(m.y)
        onPositionChanged: m => { if (pressed) update(m.y); }
    }

    // icon hit area (mute toggle etc.), above the slider area
    MouseArea {
        anchors.bottom: parent.bottom
        width: parent.width
        height: parent.width
        onClicked: root.iconClicked()
    }
}
