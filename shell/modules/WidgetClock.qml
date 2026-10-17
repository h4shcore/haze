import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

// Clock widget. Two sizes (Settings → Widgets → Size):
//   small  (160×160): just the time, sized by a slider (Settings → Widgets → Size), optionally stacked
//   medium (340×160): weekday, big light time, full date
Item {
    id: root

    property bool compact: false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── small: only the time ──
    // Sized from the real glyph shapes so the slider is honest: 100 % makes the digits touch the edges
    // of the square, lower values leave room around them. "Stacked" puts the hours over the minutes,
    // which fills a square far better than one line.
    Item {
        id: small

        anchors.fill: parent
        visible: root.compact

        readonly property bool stacked: Settings.cfg.widgetClockStacked
        readonly property real pct: Settings.cfg.widgetClockTimeSize / 100
        readonly property real gapK: 0.18      // gap between stacked lines, as a share of digit height

        // reference metrics at 100 px (widest digits, so the size never jumps from minute to minute)
        WLabel {
            id: ref
            visible: false
            text: "00"
            font.pixelSize: 100
            font.weight: Font.Light
        }
        TextMetrics { id: inkPair; font: ref.font; text: "00" }
        TextMetrics { id: inkRow; font: ref.font; text: "00:00" }

        readonly property real ink100: inkPair.tightBoundingRect.height
        readonly property real top100: ref.baselineOffset + inkPair.tightBoundingRect.y   // item top -> digit top
        readonly property real fit: stacked
            ? Math.min(width / inkPair.advanceWidth, height / (ink100 * (2 + gapK)))
            : Math.min(width / inkRow.advanceWidth, height / ink100)
        readonly property real px: isFinite(fit) && fit > 0 ? pct * 100 * fit : 52
        readonly property real inkH: ink100 * px / 100
        readonly property real inkTop: top100 * px / 100

        // one line: 14:12
        RowLayout {
            visible: !small.stacked
            anchors.horizontalCenter: parent.horizontalCenter
            y: (small.height - small.inkH) / 2 - small.inkTop
            spacing: 0

            WLabel {
                text: Qt.formatDateTime(clock.date, Settings.cfg.clock24h ? "HH" : "h")
                font.pixelSize: small.px
                font.weight: Font.Light
            }
            WLabel {
                Layout.bottomMargin: small.px * 0.07
                text: ":"
                font.pixelSize: small.px
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
                font.pixelSize: small.px
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
