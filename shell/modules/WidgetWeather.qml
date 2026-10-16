import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.common
import qs.services

// Desktop weather: big light temperature, condition + city, three-day outlook.
// Data from wttr.in (services/Weather.qml); only fetches while visible.
Item {
    id: root

    readonly property bool want: visible

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    onWantChanged: want ? Weather.hold() : Weather.release()
    Component.onCompleted: if (want) Weather.hold()
    Component.onDestruction: if (want) Weather.release()

    function deg(v) { return Math.round(v) + "°"; }

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
            text: Weather.ok ? Weather.city.toUpperCase() : "WEATHER"
            font.pixelSize: 13
            font.letterSpacing: 4
            color: Look.fgDim
        }

        RowLayout {
            spacing: 14

            Label {
                text: Weather.ok ? root.deg(Weather.temp) : "--°"
                font.pixelSize: 88
                font.weight: Font.Light
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                InkIcon {
                    text: Weather.glyph
                    pixelSize: 30
                    box: 36
                    color: Look.primary
                }
                Label {
                    Layout.maximumWidth: 150
                    text: Weather.ok ? Weather.desc : "No connection"
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                }
                Label {
                    visible: Weather.ok
                    text: "Feels " + root.deg(Weather.feels) + "  ·  " + Weather.humidity + "%"
                    font.pixelSize: 12
                    color: Look.fgDim
                }
            }
        }

        RowLayout {
            Layout.topMargin: 6
            Layout.leftMargin: 4
            spacing: 26
            visible: Weather.ok

            Repeater {
                model: Weather.days

                ColumnLayout {
                    required property var modelData

                    spacing: 0

                    Label {
                        text: modelData.name
                        font.pixelSize: 11
                        font.letterSpacing: 2
                        color: Look.fgDim
                    }
                    Label {
                        text: root.deg(Weather.fahrenheit ? modelData.maxF : modelData.maxC)
                            + "  " + root.deg(Weather.fahrenheit ? modelData.minF : modelData.minC)
                        font.pixelSize: 14
                    }
                }
            }
        }
    }
}
