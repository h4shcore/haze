import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

// Clock widget (medium): weekday, big light time with a breathing accent colon, full date.
Item {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Label {
            text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
            color: Look.primary
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 3
        }

        RowLayout {
            Layout.fillHeight: true
            spacing: 1

            Label {
                text: Qt.formatDateTime(clock.date, Settings.cfg.clock24h ? "HH" : "h")
                font.pixelSize: 66
                font.weight: Font.Light
            }
            Label {
                Layout.bottomMargin: 6
                text: ":"
                font.pixelSize: 66
                font.weight: Font.Light
                color: Look.primary

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.visible
                    NumberAnimation { to: 0.35; duration: 1200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 1200; easing.type: Easing.InOutSine }
                }
            }
            Label {
                text: Qt.formatDateTime(clock.date, "mm")
                font.pixelSize: 66
                font.weight: Font.Light
            }
            Label {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 16
                Layout.leftMargin: 6
                visible: !Settings.cfg.clock24h
                text: Qt.formatDateTime(clock.date, "AP")
                font.pixelSize: 16
                color: Look.fgDim
            }
        }

        Label {
            text: Qt.formatDateTime(clock.date, "d MMMM yyyy")
            color: Look.fgDim
            font.pixelSize: 13
        }
    }
}
