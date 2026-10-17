import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

// Clock widget. Two sizes (Settings → Widgets → Size):
//   small  (160×160): just the time, on one line or stacked (Settings → Widgets → Size)
//   medium (340×160): weekday, big light time, full date
Item {
    id: root

    property bool compact: false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── small: only the time ──
    // One line by default; "Clock stacked" (Settings → Widgets → Size) puts the hours over the minutes.
    Item {
        id: small

        anchors.fill: parent
        visible: root.compact

        readonly property bool stacked: Settings.cfg.widgetClockStacked

        // stacked sizing comes from the real glyph shapes so the two lines sit centered in the square
        readonly property real fill: 0.85      // share of the square the stacked digits cover
        readonly property real gapK: 0.18      // gap between the lines, as a share of digit height

        WLabel {
            id: ref
            visible: false
            text: "00"
            font.pixelSize: 100
            font.weight: Font.Light
        }
        TextMetrics { id: inkPair; font: ref.font; text: "00" }

        readonly property real ink100: inkPair.tightBoundingRect.height
        readonly property real top100: ref.baselineOffset + inkPair.tightBoundingRect.y   // item top -> digit top
        readonly property real fit: Math.min(width / inkPair.advanceWidth, height / (ink100 * (2 + gapK)))
        readonly property real px: isFinite(fit) && fit > 0 ? fill * 100 * fit : 52
        readonly property real inkH: ink100 * px / 100
        readonly property real inkTop: top100 * px / 100

        // one line: 14:12
        RowLayout {
            id: smallRow

            visible: !small.stacked
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
                    running: root.visible && root.compact && !small.stacked
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

        // stacked: hours over minutes
        WLabel {
            visible: small.stacked
            anchors.horizontalCenter: parent.horizontalCenter
            y: (small.height - (2 + small.gapK) * small.inkH) / 2 - small.inkTop
            text: Qt.formatDateTime(clock.date, Settings.cfg.clock24h ? "HH" : "h")
            font.pixelSize: small.px
            font.weight: Font.Light
        }
        WLabel {
            visible: small.stacked
            anchors.horizontalCenter: parent.horizontalCenter
            y: (small.height - (2 + small.gapK) * small.inkH) / 2 + small.inkH * (1 + small.gapK) - small.inkTop
            text: Qt.formatDateTime(clock.date, "mm")
            font.pixelSize: small.px
            font.weight: Font.Light
            color: Look.primary
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
