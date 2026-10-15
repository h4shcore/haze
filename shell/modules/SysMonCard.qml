import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// CPU / RAM / temperature card for the control center. Polls only while visible.
Rectangle {
    id: root

    property bool shown: false
    readonly property bool want: shown && visible

    implicitHeight: 64
    radius: 18
    color: Look.surfaceHi

    onWantChanged: want ? SysMon.hold() : SysMon.release()
    Component.onCompleted: if (want) SysMon.hold()
    Component.onDestruction: if (want) SysMon.release()

    component Stat: ColumnLayout {
        id: stat

        property string title
        property string value
        property real fraction: 0

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 2

        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: stat.title
                font.pixelSize: 11
                color: Look.fgDim
            }
            Label {
                text: stat.value
                font.bold: true
                font.pixelSize: 12
                color: Look.fg
            }
        }

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

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 16
            topMargin: 12
            bottomMargin: 12
        }
        spacing: 16

        Stat {
            title: "CPU"
            value: Math.round(SysMon.cpu * 100) + "%"
            fraction: SysMon.cpu
        }
        Stat {
            title: "RAM"
            value: SysMon.ramUsedGb.toFixed(1) + " GB"
            fraction: SysMon.ram
        }
        Stat {
            visible: SysMon.temp >= 0
            title: "Temp"
            value: Math.round(SysMon.temp) + "°C"
            fraction: SysMon.temp / 100
        }
    }
}
