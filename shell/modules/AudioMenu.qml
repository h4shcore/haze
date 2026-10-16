import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

// Audio sub-menu of the control center: pick the output and input device, per-app volume, mute the mic.
Item {
    id: root

    property bool active: false
    signal back

    opacity: active ? 1 : 0
    visible: opacity > 0
    enabled: active
    Behavior on opacity { Anim { duration: 180; curve: Look.standard } }

    function icon(n, input) {
        if (input) return "\uf130";
        return /head(phone|set)|buds|airpods/i.test(Audio.label(n)) ? "headphones" : "\uf028";
    }

    // one playing app: name, what it plays, mute button + volume slider
    component AppRow: Rectangle {
        id: app

        required property var node
        readonly property bool muted: node.audio?.muted ?? false
        readonly property real vol: node.audio?.volume ?? 0

        Layout.fillWidth: true
        implicitHeight: 62
        radius: 16
        color: Look.surfaceHi

        ColumnLayout {
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 12
                topMargin: 8
                bottomMargin: 6
            }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true

                Label {
                    Layout.fillWidth: true
                    text: Audio.appName(app.node)
                    font.pixelSize: 13
                    font.bold: true
                }
                Label {
                    text: app.muted ? "Muted" : Math.round(app.vol * 100) + "%"
                    font.pixelSize: 11
                    color: Look.fgDim
                }
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: Audio.appTitle(app.node)
                font.pixelSize: 11
                color: Look.fgDim
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                IconButton {
                    glyph: app.muted ? "\uf026" : "\uf028"
                    size: 26
                    primary: app.muted
                    onClicked: Audio.toggleNodeMute(app.node)
                }
                Slider {
                    Layout.fillWidth: true
                    value: app.muted ? 0 : app.vol
                    onMoved: v => Audio.setNodeVolume(app.node, v)
                }
            }
        }
    }

    function level(muted, vol) { return muted ? "Muted" : Math.round(vol * 100) + "%"; }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        MenuHeader {
            Layout.fillWidth: true
            title: "Audio"
            onBack: root.back()
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: flick.width
                spacing: 4

                Label {
                    Layout.leftMargin: 6
                    text: "Output"
                    font.pixelSize: 11
                    color: Look.fgDim
                }
                Label {
                    Layout.leftMargin: 6
                    visible: Audio.outputs.length === 0
                    text: "No output devices"
                    font.pixelSize: 12
                    color: Look.fgDim
                }
                Repeater {
                    model: Audio.outputs

                    MenuRow {
                        required property var modelData
                        readonly property bool current: modelData.id === Audio.sink?.id

                        Layout.fillWidth: true
                        glyph: root.icon(modelData, false)
                        title: Audio.label(modelData)
                        subtitle: current ? root.level(Audio.muted, Audio.volume) : ""
                        selected: current
                        onClicked: Audio.setOutput(modelData)
                    }
                }

                Label {
                    Layout.topMargin: 8
                    Layout.leftMargin: 6
                    text: "Apps"
                    font.pixelSize: 11
                    color: Look.fgDim
                }
                Label {
                    Layout.leftMargin: 6
                    visible: Audio.apps.length === 0
                    text: "Nothing playing"
                    font.pixelSize: 12
                    color: Look.fgDim
                }
                Repeater {
                    model: Audio.apps

                    AppRow {
                        required property var modelData
                        node: modelData
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8

                    Label {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        text: "Input"
                        font.pixelSize: 11
                        color: Look.fgDim
                    }
                    IconButton {
                        glyph: Audio.micMuted ? "mic_off" : "\uf130"
                        size: 28
                        primary: Audio.micMuted
                        visible: Audio.source !== null
                        onClicked: Audio.toggleMicMute()
                    }
                }
                Label {
                    Layout.leftMargin: 6
                    visible: Audio.inputs.length === 0
                    text: "No input devices"
                    font.pixelSize: 12
                    color: Look.fgDim
                }
                Repeater {
                    model: Audio.inputs

                    MenuRow {
                        required property var modelData
                        readonly property bool current: modelData.id === Audio.source?.id

                        Layout.fillWidth: true
                        glyph: root.icon(modelData, true)
                        title: Audio.label(modelData)
                        subtitle: current ? root.level(Audio.micMuted, Audio.micVolume) : ""
                        selected: current
                        onClicked: Audio.setInput(modelData)
                    }
                }
            }
        }
    }
}
