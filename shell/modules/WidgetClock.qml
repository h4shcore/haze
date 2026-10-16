import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

// Clock widget. Two sizes (Settings → Widgets → Size):
//   small  (160×160): just the time, centered, with a breathing accent colon
//   medium (340×160): weekday, big light time, full date
Item {
    id: root

    property bool compact: false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── small: only the time ──
    Item {
        anchors.fill: parent
        visible: root.compact

        RowLayout {
            id: smallRow

            anchors.centerIn: parent
            spacing: 0
            // never wider than the card, whatever the font turns out to be
            scale: Math.min(1, parent.width / Math.max(1, implicitWidth))

            WLabel {
                text: Qt.formatDateTime(clock.date, Settings.cfg.clock24h ? "HH" : "h")
                font.pixelSize: 52
                font.weight: Font.Light
            }
            WLabel {
                Layout.bottomMargin: 4
                text: ":"
                font.pixelSize: 52
                font.weight: Font.Light
                color: Look.primary

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.visible && root.compact
                    NumberAnimation { to: 0.35; duration: 1200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 1200; easing.type: Easing.InOutSine }
                }
            }
            WLabel {
                text: Qt.formatDateTime(clock.date, "mm")
                font.pixelSize: 52
                font.weight: Font.Light
            }
        }
    }

    // ── medium: weekday, time, date ──
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: !root.compact

        WLabel {
            text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
            color: Look.primary
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 3
        }

        RowLayout {
            Layout.fillHeight: true
            spacing: 1

            WLabel {
                text: Qt.formatDateTime(clock.date, Settings.cfg.clock24h ? "HH" : "h")
                font.pixelSize: 66
                font.weight: Font.Light
            }
            WLabel {
                Layout.bottomMargin: 6
                text: ":"
                font.pixelSize: 66
                font.weight: Font.Light
                color: Look.primary

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.visible && !root.compact
                    NumberAnimation { to: 0.35; duration: 1200; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 1200; easing.type: Easing.InOutSine }
                }
            }
            WLabel {
                text: Qt.formatDateTime(clock.date, "mm")
                font.pixelSize: 66
                font.weight: Font.Light
            }
            WLabel {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 16
                Layout.leftMargin: 6
                visible: !Settings.cfg.clock24h
                text: Qt.formatDateTime(clock.date, "AP")
                font.pixelSize: 16
                color: Look.fgDim
            }
        }

        WLabel {
            text: Qt.formatDateTime(clock.date, "d MMMM yyyy")
            color: Look.fgDim
            font.pixelSize: 13
        }
    }
}
