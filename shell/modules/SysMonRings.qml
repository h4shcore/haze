import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// Desktop system monitor: three concentric rings (CPU, memory, temperature) and a quiet legend.
Rectangle {
    id: root

    readonly property bool want: visible

    radius: 28
    color: Look.surface
    border.width: 1
    border.color: Qt.alpha(Look.outline, 0.6)

    onWantChanged: want ? SysMon.hold() : SysMon.release()
    Component.onCompleted: if (want) SysMon.hold()
    Component.onDestruction: if (want) SysMon.release()

    RowLayout {
        anchors {
            fill: parent
            margins: 18
        }
        spacing: 20

        Canvas {
            id: rings

            Layout.preferredWidth: 114
            Layout.preferredHeight: 114
            Layout.alignment: Qt.AlignVCenter

            property real cpu: SysMon.cpu
            property real ram: SysMon.ram
            property real temp: SysMon.temp < 0 ? 0 : Math.min(1, SysMon.temp / 100)
            Behavior on cpu { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            Behavior on ram { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            Behavior on temp { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
            onCpuChanged: requestPaint()
            onRamChanged: requestPaint()
            onTempChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 8;
                ctx.lineCap = "round";
                const c = width / 2;
                const set = [
                    { r: 52, v: cpu, a: 1.0 },
                    { r: 40, v: ram, a: 0.7 },
                    { r: 28, v: temp, a: 0.45 }
                ];
                for (const s of set) {
                    ctx.strokeStyle = Qt.alpha(Look.fg, 0.1);
                    ctx.beginPath();
                    ctx.arc(c, c, s.r, 0, Math.PI * 2);
                    ctx.stroke();
                    if (s.v > 0.01) {
                        ctx.strokeStyle = Qt.alpha(Look.primary, s.a);
                        ctx.beginPath();
                        ctx.arc(c, c, s.r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, s.v));
                        ctx.stroke();
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 10

            component Stat: RowLayout {
                id: row

                property string name
                property string value
                property real shade: 1

                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Qt.alpha(Look.primary, row.shade)
                }
                Label {
                    Layout.fillWidth: true
                    text: row.name
                    font.pixelSize: 12
                    color: Look.fgDim
                }
                Label {
                    text: row.value
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            Stat {
                name: "CPU"
                value: Math.round(SysMon.cpu * 100) + "%"
                shade: 1.0
            }
            Stat {
                name: "Memory"
                value: SysMon.ramUsedGb.toFixed(1) + " GB"
                shade: 0.7
            }
            Stat {
                visible: SysMon.temp >= 0
                name: "Temp"
                value: Math.round(SysMon.temp) + "°C"
                shade: 0.45
            }
        }
    }
}
