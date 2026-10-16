import QtQuick
import QtQuick.Layouts

// One selectable row in a control center sub-menu (wifi network, audio device).
Rectangle {
    id: root

    property string glyph
    property real glyphOpacity: 1
    property string title
    property string subtitle
    property string trailing
    property bool selected: false
    signal clicked

    implicitHeight: 44
    radius: 16
    color: selected ? Look.primary : mouse.containsMouse ? Look.surfaceHiest : Look.surfaceHi
    scale: mouse.pressed ? 0.98 : 1

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { Anim { duration: Look.dur.fast } }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 14
            rightMargin: 12
        }
        spacing: 12

        InkIcon {
            text: root.glyph
            pixelSize: 16
            box: 24
            opacity: root.glyphOpacity
            color: root.selected ? Look.primaryFg : Look.fg
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: 13
                font.bold: root.selected
                color: root.selected ? Look.primaryFg : Look.fg
            }
            Label {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                font.pixelSize: 11
                color: root.selected ? Look.primaryFg : Look.fgDim
            }
        }
        InkIcon {
            visible: root.trailing !== ""
            text: root.trailing
            pixelSize: 13
            box: 20
            color: root.selected ? Look.primaryFg : Look.fgDim
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
