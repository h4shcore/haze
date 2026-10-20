import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

RowLayout {
    spacing: 6

    readonly property string timeFormat: Settings.cfg.clock24h
        ? (Settings.cfg.clockSeconds ? "HH:mm:ss" : "HH:mm")
        : (Settings.cfg.clockSeconds ? "h:mm:ss AP" : "h:mm AP")

    SystemClock {
        id: clock
        precision: Settings.cfg.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Label {
        text: Qt.formatDateTime(clock.date, parent.timeFormat)
        font.bold: Settings.cfg.clockBold
        font.pixelSize: Settings.cfg.clockSize
    }
    Label {
        visible: Settings.cfg.dateFormat !== ""
        text: Qt.formatDateTime(clock.date, Settings.cfg.dateFormat)
        color: Look.fgDim
        font.pixelSize: Settings.cfg.clockSize - 1
    }
}
