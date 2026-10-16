import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// System monitor widget (small): three concentric rings (CPU, memory, temperature),
// CPU % in the middle and memory + temperature underneath. Polls only while visible.
Item {
    id: root

    readonly property bool want: visible

    onWantChanged: want ? SysMon.hold() : SysMon.release()
    Component.onCompleted: if (want) SysMon.hold()
    Component.onDestruction: if (want) SysMon.release()

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96

            Canvas {
                id: rings

                anchors.fill: parent

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
                    ctx.lineWidth = 7;
                    ctx.lineCap = "round";
                    const c = width / 2;
                    const set = [
                        { r: 42, v: cpu, a: 1.0 },
                        { r: 32, v: ram, a: 0.7 },
                        { r: 22, v: temp, a: 0.45 }
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

            WLabel {
                anchors.centerIn: parent
                text: Math.round(SysMon.cpu * 100) + "%"
                font.pixelSize: 14
                font.bold: true
            }
        }

        WLabel {
            Layout.alignment: Qt.AlignHCenter
            text: SysMon.ramUsedGb.toFixed(1) + " GB" + (SysMon.temp >= 0 ? "  ·  " + Math.round(SysMon.temp) + "°" : "")
            font.pixelSize: 12
            color: Look.fgDim
        }
    }
}
