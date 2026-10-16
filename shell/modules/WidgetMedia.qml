import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.common
import qs.services

// Desktop now-playing: big art, light type, a hairline progress bar and three quiet controls.
Item {
    id: root

    readonly property MprisPlayer p: Players.active
    readonly property bool playing: p?.isPlaying ?? false

    implicitWidth: 420
    implicitHeight: 128

    // position isn't pushed by MPRIS, so poke it while playing and visible
    Timer {
        running: root.visible && root.playing
        interval: 1000
        repeat: true
        onTriggered: if (root.p) root.p.positionChanged()
    }

    component Ctl: Item {
        id: ctl

        property string glyph
        property bool usable: true
        signal clicked

        implicitWidth: 30
        implicitHeight: 30
        opacity: usable ? (mouse.containsMouse ? 1 : 0.85) : 0.3
        scale: mouse.pressed ? 0.9 : 1
        Behavior on scale { Anim { duration: Look.dur.fast } }

        InkIcon {
            anchors.centerIn: parent
            text: ctl.glyph
            pixelSize: 16
            box: 26
            color: Look.fg
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (ctl.usable) ctl.clicked()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 20

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.35
            shadowBlur: 0.8
            shadowVerticalOffset: 3
        }

        ClippingRectangle {
            Layout.preferredWidth: 128
            Layout.preferredHeight: 128
            radius: 30
            color: Look.surfaceHi
            scale: root.playing ? 1 : 0.95
            Behavior on scale { Anim {} }

            Image {
                id: art
                anchors.fill: parent
                source: root.p?.trackArtUrl ?? ""
                sourceSize: Qt.size(320, 320)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { Anim { duration: 300; curve: Look.standard } }
            }
            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "\uf001"
                font.pixelSize: 34
                color: Look.fgDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Label {
                Layout.fillWidth: true
                text: (root.p?.identity ?? "").toUpperCase()
                color: Look.primary
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 3
            }
            Label {
                Layout.fillWidth: true
                text: root.p?.trackTitle || "Nothing playing"
                font.pixelSize: 24
                font.weight: Font.Medium
            }
            Label {
                Layout.fillWidth: true
                text: root.p?.trackArtist ?? ""
                color: Look.fgDim
                font.pixelSize: 15
            }

            // hairline progress, click to seek
            Item {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.preferredHeight: 12

                readonly property real frac: root.p && root.p.length > 0 ? Math.min(1, root.p.position / root.p.length) : 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 3
                    radius: 2
                    color: Qt.alpha(Look.fg, 0.2)

                    Rectangle {
                        width: parent.width * parent.parent.frac
                        height: parent.height
                        radius: 2
                        color: Look.primary
                        Behavior on width { Anim { duration: 900; curve: Look.smooth } }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.p?.canSeek ?? false
                    onClicked: m => { if (root.p) root.p.position = m.x / width * root.p.length; }
                }
            }

            RowLayout {
                Layout.topMargin: 4
                spacing: 18

                Ctl {
                    glyph: "\uf048"
                    usable: root.p?.canGoPrevious ?? false
                    onClicked: root.p.previous()
                }

                // play/pause: circle when paused, rounded square when playing
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: root.playing ? 15 : 21
                    color: Look.primary
                    opacity: (root.p?.canTogglePlaying ?? false) ? 1 : 0.4
                    scale: playMouse.pressed ? 0.92 : 1
                    Behavior on radius { Anim {} }
                    Behavior on scale { Anim { duration: Look.dur.fast } }

                    InkIcon {
                        anchors.centerIn: parent
                        text: root.playing ? "\uf04c" : "\uf04b"
                        pixelSize: 16
                        box: 24
                        color: Look.primaryFg
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        onClicked: if (root.p) root.p.togglePlaying()
                    }
                }

                Ctl {
                    glyph: "\uf051"
                    usable: root.p?.canGoNext ?? false
                    onClicked: root.p.next()
                }
            }
        }
    }
}
