import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.common
import qs.services

// Now-playing widget. Three sizes (Settings → Widgets → Size):
//   small  (160×160): just the album art filling the card, tap it to play / pause
//   medium (340×160): cover on the left; title, artist, the line being sung, progress and controls on the right,
//                     with a faint audio spectrum behind
//   large  (340×340): cover and title on top, synced lyrics (previous / current / next line), spectrum, progress, controls
// Lyrics come from lrclib.net (services/Lyrics.qml), the spectrum from cava (services/Cava.qml);
// both can be switched off in Settings → Widgets.
// With no player open it shows a pulsing music-note skeleton (or hides, if Settings → Widgets says so).
Item {
    id: root

    property bool compact: false     // small
    property bool large: false

    readonly property MprisPlayer p: Players.active
    readonly property bool playing: p?.isPlaying ?? false
    readonly property bool idle: p === null

    readonly property bool wantLyrics: Settings.cfg.widgetMediaLyrics && !compact && visible && !idle
    readonly property bool showViz: Settings.cfg.widgetMediaViz && !compact

    // the lyrics service only works while a widget asks for it
    property bool lyricsHeld: false
    function syncLyrics() {
        if (wantLyrics && !lyricsHeld) {
            lyricsHeld = true;
            Lyrics.hold();
        } else if (!wantLyrics && lyricsHeld) {
            lyricsHeld = false;
            Lyrics.release();
        }
    }
    onWantLyricsChanged: syncLyrics()
    Component.onCompleted: syncLyrics()
    Component.onDestruction: if (lyricsHeld) Lyrics.release()

    // shared pulse for the skeleton placeholders
    property real pulse: 1
    SequentialAnimation on pulse {
        loops: Animation.Infinite
        running: root.visible && root.idle
        NumberAnimation { to: 0.35; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
    }

    // position isn't pushed by MPRIS, so poke it while playing and visible (faster while lyrics are scrolling)
    Timer {
        running: root.visible && root.playing
        interval: root.wantLyrics && Lyrics.ready ? 350 : 1000
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

    // album art with the music-note fallback
    component Art: ClippingRectangle {
        id: a

        property var p
        property bool playing: false
        property bool idle: false
        property real pulse: 1
        property int px: 30

        color: Look.surfaceHiest
        scale: playing ? 1 : 0.95
        Behavior on scale { Anim {} }

        Image {
            id: img
            anchors.fill: parent
            source: a.p?.trackArtUrl ?? ""
            sourceSize: Qt.size(320, 320)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { Anim { duration: 300; curve: Look.standard } }
        }
        Icon {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            text: "\uf001"
            font.pixelSize: a.px
            color: Look.fgDim
            opacity: a.idle ? a.pulse : 1
        }
    }

    // hairline progress, click to seek
    component Progress: Item {
        id: pg

        property var p
        readonly property real frac: p && p.length > 0 ? Math.min(1, p.position / p.length) : 0

        implicitHeight: 10

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 3
            radius: 2
            color: Qt.alpha(Look.fg, 0.15)

            Rectangle {
                width: parent.width * pg.frac
                height: parent.height
                radius: 2
                color: Look.primary
                Behavior on width { Anim { duration: 900; curve: Look.smooth } }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: pg.p?.canSeek ?? false
            onClicked: m => { if (pg.p) pg.p.position = m.x / width * pg.p.length; }
        }
    }

    // previous / play-pause / next. Play-pause is a circle when paused, a rounded square when playing
    component Controls: RowLayout {
        id: ct

        property var p
        property bool playing: false

        spacing: 14

        Ctl {
            glyph: "\uf048"
            usable: ct.p?.canGoPrevious ?? false
            onClicked: ct.p.previous()
        }
        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: ct.playing ? 13 : 19
            color: Look.primary
            opacity: (ct.p?.canTogglePlaying ?? false) ? 1 : 0.4
            scale: playMouse.pressed ? 0.92 : 1
            Behavior on radius { Anim {} }
            Behavior on scale { Anim { duration: Look.dur.fast } }

            InkIcon {
                anchors.centerIn: parent
                text: ct.playing ? "\uf04c" : "\uf04b"
                pixelSize: 15
                box: 22
                color: Look.primaryFg
            }
            MouseArea {
                id: playMouse
                anchors.fill: parent
                onClicked: if (ct.p) ct.p.togglePlaying()
            }
        }
        Ctl {
            glyph: "\uf051"
            usable: ct.p?.canGoNext ?? false
            onClicked: ct.p.next()
        }
    }

    // previous / current / next lyric line, centered
    component LyricLines: Item {
        id: lv

        clip: true

        ColumnLayout {
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            WLabel {
                Layout.fillWidth: true
                text: Lyrics.prev
                color: Look.fgDim
                opacity: 0.55
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
            WLabel {
                id: curLine
                Layout.fillWidth: true
                text: Lyrics.cur
                color: Lyrics.ready ? Look.fg : Look.fgDim
                font.pixelSize: 16
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                onTextChanged: pop.restart()

                NumberAnimation {
                    id: pop
                    target: curLine
                    property: "opacity"
                    from: 0.25
                    to: 1
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            WLabel {
                Layout.fillWidth: true
                text: Lyrics.next
                color: Look.fgDim
                opacity: 0.55
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
            }
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

    // ── medium: faint spectrum behind everything ──
    Spectrum {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 46
        z: -1
        opacity: 0.16
        visible: root.showViz && !root.compact && !root.large
        active: root.playing
    }

    // ── medium: cover, title, artist, current lyric line, progress, controls ──
    RowLayout {
        anchors.fill: parent
        spacing: 16
        visible: !root.compact && !root.large

        Art {
            Layout.preferredWidth: root.height
            Layout.preferredHeight: root.height
            radius: 20
            p: root.p
            playing: root.playing
            idle: root.idle
            pulse: root.pulse
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

            // the line being sung (hidden when the lyrics are off or not found)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                WLabel {
                    id: medLine
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    visible: root.wantLyrics && Lyrics.ready && !root.large
                    text: Lyrics.cur
                    color: Look.primary
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    onTextChanged: medPop.restart()

                    NumberAnimation {
                        id: medPop
                        target: medLine
                        property: "opacity"
                        from: 0.25
                        to: 1
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Progress {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
                p: root.p
            }

            Controls {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                p: root.p
                playing: root.playing
            }
        }
    }

    // ── large: cover + title, lyrics, spectrum, progress, controls ──
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        visible: !root.compact && root.large

        // fixed height: a nested layout with fill children would otherwise grab the spare space
        // and squash the lyrics
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: 84
            spacing: 14

            Art {
                Layout.preferredWidth: 84
                Layout.preferredHeight: 84
                radius: 16
                px: 26
                p: root.p
                playing: root.playing
                idle: root.idle
                pulse: root.pulse
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item { Layout.fillHeight: true }
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
                    text: root.p?.trackTitle || "Nothing playing"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                WLabel {
                    Layout.fillWidth: true
                    visible: !root.idle
                    text: root.p?.trackArtist ?? ""
                    color: Look.fgDim
                    font.pixelSize: 13
                }
                Item { Layout.fillHeight: true }
            }
        }

        LyricLines {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 80
            visible: root.wantLyrics
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.wantLyrics
        }

        Spectrum {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            visible: root.showViz && root.large
            active: root.playing
        }

        Progress {
            Layout.fillWidth: true
            Layout.preferredHeight: 10
            p: root.p
        }

        Controls {
            Layout.alignment: Qt.AlignHCenter
            p: root.p
            playing: root.playing
        }
    }
}
