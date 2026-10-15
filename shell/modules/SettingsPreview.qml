import QtQuick
import QtQuick.Layouts
import qs.common

// Live miniature of the shell (collapsed + expanded notch) that follows the Shape settings.
Item {
    id: root

    implicitHeight: 208

    component Mini: Item {
        id: m

        property bool expanded: false
        property string caption

        width: 250
        height: 150

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Look.surface
            border.width: 1
            border.color: Qt.alpha(Look.outline, 0.6)
        }

        // the "desktop" inside the border
        Rectangle {
            id: desk
            anchors.fill: parent
            anchors.margins: Math.max(2, Look.border * 1.3)
            radius: 12
            clip: true
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Look.primary, 0.32) }
                GradientStop { position: 1; color: Look.surfaceHiest }
            }

            Behavior on anchors.margins { Anim { duration: Look.dur.fast } }

            // fake window
            Rectangle {
                x: 22
                y: m.expanded ? 96 : 52
                width: 90
                height: 40
                radius: 8
                color: Qt.alpha(Look.fg, 0.1)
            }

            // the notch (top corners are clipped by the desktop)
            Rectangle {
                id: notch

                readonly property real r: m.expanded ? Look.panelRadius * 0.55 : Look.notchRadius * 0.55

                x: (parent.width - width) / 2
                y: -r
                width: m.expanded ? 168 : 74
                height: (m.expanded ? 80 : 18) + r
                radius: r
                color: Look.surface

                Behavior on width { Anim {} }
                Behavior on height { Anim {} }
                Behavior on radius { Anim { duration: Look.dur.fast } }

                Label {
                    x: (parent.width - width) / 2
                    y: notch.r + 2
                    text: "12:34"
                    font.pixelSize: 10
                    font.bold: true
                }

                Row {
                    visible: m.expanded
                    x: 12
                    y: notch.r + 22
                    spacing: 6

                    Repeater {
                        model: 3

                        Rectangle {
                            required property int index
                            width: 44
                            height: 34
                            radius: Math.min(11, Look.panelRadius * 0.4)
                            color: index === 0 ? Look.secondaryContainer : Look.surfaceHi

                            Rectangle {
                                x: 7
                                y: 7
                                width: 10
                                height: 10
                                radius: 5
                                color: index === 0 ? Look.primary : Qt.alpha(Look.fg, 0.2)
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 48

        Column {
            spacing: 10
            Mini { expanded: false }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Collapsed"
                color: Look.fgDim
                font.pixelSize: 11
            }
        }
        Column {
            spacing: 10
            Mini { expanded: true }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Hover / expanded"
                color: Look.fgDim
                font.pixelSize: 11
            }
        }
    }
}
