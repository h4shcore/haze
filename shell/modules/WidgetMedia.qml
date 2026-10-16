import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.common
import qs.services

// Now-playing widget. Two sizes (Settings → Widgets → Size):
//   small  (160×160): just the album art filling the card, tap it to play / pause
//   medium (340×160): cover on the left; title, artist, hairline progress and controls on the right
// With no player open it shows a pulsing music-note skeleton (or hides, if Settings → Widgets says so).
Item {
    id: root

    property bool compact: false

    readonly property MprisPlayer p: Players.active
    readonly property bool playing: p?.isPlaying ?? false
    readonly property bool idle: p === null

    // shared pulse for the skeleton placeholders
    property real pulse: 1
    SequentialAnimation on pulse {
        loops: Animation.Infinite
        running: root.visible && root.idle
        NumberAnimation { to: 0.35; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
    }

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

    // ── small: only the album ──
    ClippingRectangle {
        anchors.fill: parent
        visible: root.compact
        radius: 27          // card radius (28) minus its 1px border
        color: Look.surfaceHiest

        Image {
            id: artSmall
            anchors.fill: parent
            source: root.p?.trackArtUrl ?? ""
            sourceSize: Qt.size(480, 480)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? (root.playing ? 1 : 0.55) : 0
            Behavior on opacity { Anim { duration: 300; curve: Look.standard } }
        }
        Icon {
            anchors.centerIn: parent
            visible: artSmall.status !== Image.Ready
            text: "\uf001"
            font.pixelSize: 40
            color: Look.fgDim
            opacity: root.idle ? root.pulse : 1
        }
        // paused hint
        InkIcon {
            anchors.centerIn: parent
            visible: artSmall.status === Image.Ready && !root.playing
            text: "\uf04b"
            pixelSize: 26
            box: 36
            color: Look.fg
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.p?.canTogglePlaying ?? false
            onClicked: if (root.p) root.p.togglePlaying()
        }
    }

    // ── medium: cover, title, artist, progress, controls ──
    RowLayout {
        anchors.fill: parent
        spacing: 16
        visible: !root.compact

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
                opacity: root.idle ? root.pulse : 1
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            WLabel {
                Layout.fillWidth: true
                visible: !root.idle
                text: (root.p?.identity ?? "").toUpperCase()
                color: Look.primary
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 2
            }
            WLabel {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: !root.idle
                text: root.p?.trackTitle || "Nothing playing"
                font.pixelSize: 17
                font.weight: Font.Medium
            }
            WLabel {
                Layout.fillWidth: true
                visible: !root.idle
                text: root.p?.trackArtist ?? ""
                color: Look.fgDim
                font.pixelSize: 13
            }

            // skeleton: stand-ins for source, title and artist while nothing is playing
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 8
                Layout.topMargin: 2
                visible: root.idle
                radius: 4
                color: Qt.alpha(Look.primary, 0.5)
                opacity: root.pulse
            }
            Rectangle {
                Layout.preferredWidth: 130
                Layout.preferredHeight: 14
                Layout.topMargin: 10
                visible: root.idle
                radius: 7
                color: Qt.alpha(Look.fg, 0.16)
                opacity: root.pulse
            }
            Rectangle {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 11
                Layout.topMargin: 8
                visible: root.idle
                radius: 5.5
                color: Qt.alpha(Look.fg, 0.1)
                opacity: root.pulse
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
