import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.common
import qs.services

// Now-playing widget (medium): cover on the left; title, artist, hairline progress and controls on the right.
Item {
    id: root

    readonly property MprisPlayer p: Players.active
    readonly property bool playing: p?.isPlaying ?? false

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

        implicitWidth: 28
        implicitHeight: 28
        opacity: usable ? (mouse.containsMouse ? 1 : 0.85) : 0.3
        scale: mouse.pressed ? 0.9 : 1
        Behavior on scale { Anim { duration: Look.dur.fast } }

        InkIcon {
            anchors.centerIn: parent
            text: ctl.glyph
            pixelSize: 15
            box: 24
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
        spacing: 16

        ClippingRectangle {
            Layout.preferredWidth: root.height
            Layout.preferredHeight: root.height
            radius: 20
            color: Look.surfaceHiest
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
                font.pixelSize: 30
                color: Look.fgDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: (root.p?.identity ?? "").toUpperCase()
                color: Look.primary
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 2
            }
            Label {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: root.p?.trackTitle || "Nothing playing"
                font.pixelSize: 17
                font.weight: Font.Medium
            }
            Label {
                Layout.fillWidth: true
                text: root.p?.trackArtist ?? ""
                color: Look.fgDim
                font.pixelSize: 13
            }

            Item { Layout.fillHeight: true }

            // hairline progress, click to seek
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 10

                readonly property real frac: root.p && root.p.length > 0 ? Math.min(1, root.p.position / root.p.length) : 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 3
                    radius: 2
                    color: Qt.alpha(Look.fg, 0.15)

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
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                spacing: 14

                Ctl {
                    glyph: "\uf048"
                    usable: root.p?.canGoPrevious ?? false
                    onClicked: root.p.previous()
                }

                // play/pause: circle when paused, rounded square when playing
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: root.playing ? 13 : 19
                    color: Look.primary
                    opacity: (root.p?.canTogglePlaying ?? false) ? 1 : 0.4
                    scale: playMouse.pressed ? 0.92 : 1
                    Behavior on radius { Anim {} }
                    Behavior on scale { Anim { duration: Look.dur.fast } }

                    InkIcon {
                        anchors.centerIn: parent
                        text: root.playing ? "\uf04c" : "\uf04b"
                        pixelSize: 15
                        box: 22
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
