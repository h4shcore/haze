import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// Tall CPU / RAM / temperature panel that sits on the right side of the control center.
// Polls only while visible.
Rectangle {
    id: root

    property bool shown: false
    readonly property bool want: shown && visible

    radius: 18
    color: Look.surfaceHi

    onWantChanged: want ? SysMon.hold() : SysMon.release()
    Component.onCompleted: if (want) SysMon.hold()
    Component.onDestruction: if (want) SysMon.release()

    component Stat: ColumnLayout {
        id: stat

        property string title
        property string value
        property string detail
        property real fraction: 0

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 1

        Label {
            text: stat.title
            font.pixelSize: 11
            color: Look.fgDim
        }
        Label {
            text: stat.value
            font.bold: true
            font.pixelSize: 24
            color: stat.fraction > 0.9 ? Look.error : Look.fg
        }
        Label {
            Layout.fillWidth: true
            text: stat.detail
            font.pixelSize: 11
            color: Look.fgDim
            visible: text !== ""
        }
        Item { Layout.fillHeight: true }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 5
            radius: 3
            color: Look.surfaceHiest

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, stat.fraction))
                height: parent.height
                radius: 3
                color: stat.fraction > 0.9 ? Look.error : Look.primary
                Behavior on width { Anim { duration: 600; curve: Look.smooth } }
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 14
        }
        spacing: 12

        Stat {
            title: "CPU"
            value: Math.round(SysMon.cpu * 100) + "%"
            fraction: SysMon.cpu
        }
        Stat {
            title: "Memory"
            value: SysMon.ramUsedGb.toFixed(1) + " GB"
            detail: "of " + SysMon.ramTotalGb.toFixed(0) + " GB"
            fraction: SysMon.ram
        }
        Stat {
            visible: SysMon.temp >= 0
            title: "Temperature"
            value: Math.round(SysMon.temp) + "°C"
            fraction: SysMon.temp / 100
        }
    }
}
