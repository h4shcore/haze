import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// One quiet line of CPU / RAM / temperature. Polls only while visible.
Item {
    id: root

    property bool shown: false
    readonly property bool want: shown && visible

    implicitHeight: 20

    onWantChanged: want ? SysMon.hold() : SysMon.release()
    Component.onCompleted: if (want) SysMon.hold()
    Component.onDestruction: if (want) SysMon.release()

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "CPU " + Math.round(SysMon.cpu * 100) + "%"
            font.pixelSize: 11
            color: SysMon.cpu > 0.9 ? Look.error : Look.fgDim
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "RAM " + SysMon.ramUsedGb.toFixed(1) + " GB"
            font.pixelSize: 11
            color: SysMon.ram > 0.9 ? Look.error : Look.fgDim
        }
        Label {
            Layout.fillWidth: true
            visible: SysMon.temp >= 0
            horizontalAlignment: Text.AlignHCenter
            text: Math.round(SysMon.temp) + "°C"
            font.pixelSize: 11
            color: SysMon.temp > 85 ? Look.error : Look.fgDim
        }
    }
}
