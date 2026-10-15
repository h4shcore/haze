import QtQuick

// Pill-shaped segmented picker with a sliding highlight.
Item {
    id: root

    property var options: []        // [{ v, l }]
    property var value
    property int segWidth: options.length > 4 ? 80 : 96
    signal picked(var v)

    readonly property int idx: Math.max(0, options.findIndex(o => o.v === value))

    implicitWidth: options.length * segWidth + 8
    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Look.surfaceHiest
    }

    Rectangle {
        x: 4 + root.idx * root.segWidth
        y: 4
        width: root.segWidth
        height: root.height - 8
        radius: height / 2
        color: Look.primary
        Behavior on x { Anim {} }
    }

    Repeater {
        model: root.options

        Item {
            id: seg

            required property var modelData
            required property int index
            readonly property bool current: root.idx === index

            x: 4 + index * root.segWidth
            y: 4
            width: root.segWidth
            height: root.height - 8

            Label {
                anchors.centerIn: parent
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                text: seg.modelData.l
                font.pixelSize: 12
                font.bold: seg.current
                color: seg.current ? Look.primaryFg : (segMouse.containsMouse ? Look.fg : Look.fgDim)
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            MouseArea {
                id: segMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.picked(seg.modelData.v)
            }
        }
    }
}
