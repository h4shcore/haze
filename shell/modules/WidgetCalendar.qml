import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs.common

// Desktop calendar: current month, today in a soft circle. No card, just type on the wallpaper.
Item {
    id: root

    readonly property real cell: 36
    readonly property var today: new Date(clk.date)
    readonly property int firstDow: Qt.locale().firstDayOfWeek % 7
    readonly property var gridStart: {
        const first = new Date(today.getFullYear(), today.getMonth(), 1);
        const offset = (first.getDay() - firstDow + 7) % 7;
        return new Date(today.getFullYear(), today.getMonth(), 1 - offset);
    }

    implicitWidth: cell * 7
    implicitHeight: col.implicitHeight

    SystemClock {
        id: clk
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 6

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.35
            shadowBlur: 0.8
            shadowVerticalOffset: 3
        }

        Label {
            Layout.leftMargin: 4
            Layout.bottomMargin: 4
            text: Qt.formatDate(root.today, "MMMM  yyyy").toUpperCase()
            font.pixelSize: 13
            font.letterSpacing: 4
            color: Look.fgDim
        }

        Row {
            Repeater {
                model: 7

                Label {
                    required property int index
                    width: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((root.firstDow + index) % 7, Locale.NarrowFormat)
                    font.pixelSize: 11
                    color: Look.fgDim
                    opacity: 0.7
                }
            }
        }

        Grid {
            columns: 7

            Repeater {
                model: 42

                Item {
                    id: day

                    required property int index
                    readonly property date d: new Date(root.gridStart.getFullYear(), root.gridStart.getMonth(), root.gridStart.getDate() + index)
                    readonly property bool inMonth: d.getMonth() === root.today.getMonth()
                    readonly property bool isToday: d.getFullYear() === root.today.getFullYear()
                        && d.getMonth() === root.today.getMonth() && d.getDate() === root.today.getDate()

                    width: root.cell
                    height: root.cell

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: 15
                        color: Look.primary
                        visible: day.isToday
                    }
                    Label {
                        anchors.centerIn: parent
                        text: day.d.getDate()
                        font.pixelSize: 13
                        font.bold: day.isToday
                        color: day.isToday ? Look.primaryFg : Look.fg
                        opacity: day.inMonth ? 1 : 0.25
                    }
                }
            }
        }
    }
}
