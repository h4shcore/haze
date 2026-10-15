import QtQuick

// Small on/off switch.
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 26
    radius: height / 2
    color: checked ? Look.primary : Look.surfaceHiest
    opacity: enabled ? 1 : 0.4

    Behavior on color { ColorAnimation { duration: 180 } }

    Rectangle {
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        width: mouse.pressed ? 24 : 20
        height: 20
        radius: 10
        color: root.checked ? Look.primaryFg : Look.fgDim

        Behavior on x { Anim { duration: Look.dur.fast } }
        Behavior on width { Anim { duration: Look.dur.fast } }
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: root.toggled(!root.checked)
    }
}
