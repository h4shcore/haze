import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Session lock (ext-session-lock). One surface per screen; they all show the same state because
// the typed password lives in the Lock service. Whichever surface the compositor gives keyboard
// focus to receives the keys.
//
// Type to enter the password · Enter unlock · Backspace delete (Ctrl+Backspace clears) · Esc clears
WlSessionLock {
    id: lock

    locked: Lock.locked

    WlSessionLockSurface {
        id: surf

        color: Look.surface

        Item {
            id: scene

            property bool shown: false

            anchors.fill: parent
            focus: true

            Component.onCompleted: {
                shown = true;
                forceActiveFocus();
            }

            Keys.onPressed: ev => {
                const ctrl = (ev.modifiers & Qt.ControlModifier) !== 0;
                const meta = (ev.modifiers & Qt.MetaModifier) !== 0;
                if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) Lock.submit();
                else if (ev.key === Qt.Key_Backspace) Lock.backspace(ctrl);
                else if (ev.key === Qt.Key_Escape || (ctrl && ev.key === Qt.Key_U)) Lock.clear();
                else if (!ctrl && !meta && ev.text.length > 0 && ev.text.charCodeAt(0) >= 32 && ev.text.charCodeAt(0) !== 127)
                    Lock.type(ev.text);
                ev.accepted = true;
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            // ── background: blurred wallpaper under a scrim ──
            Image {
                id: wall

                anchors.fill: parent
                visible: false
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
                sourceSize: Qt.size(surf.width > 0 ? surf.width : 1920, surf.height > 0 ? surf.height : 1080)
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                blurEnabled: Settings.cfg.lockBlur
                blur: 1.0
                blurMax: 64
                saturation: -0.1
                opacity: wall.status === Image.Ready ? 1 : 0

                Behavior on opacity { Anim { duration: Look.dur.slow; curve: Look.standard } }
            }
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Look.surface.r, Look.surface.g, Look.surface.b, wall.status === Image.Ready ? 0.45 : 0)

                Behavior on color { ColorAnimation { duration: Look.dur.slow } }
            }

            // ── clock + password ──
            ColumnLayout {
                id: content

                readonly property int timeSize: Math.round(Math.min(surf.height * 0.2, 180))

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -surf.height * 0.06
                spacing: 0
                opacity: scene.shown ? 1 : 0

                transform: Translate {
                    y: scene.shown ? 0 : 14

                    Behavior on y { Anim { duration: Look.dur.slow; curve: Look.smooth } }
                }
                Behavior on opacity { Anim { duration: Look.dur.slow; curve: Look.standard } }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Look.fg
                    opacity: 0.8
                    font.family: Look.widgetFont
                    font.pixelSize: Math.round(content.timeSize * 0.17)
                    font.weight: Font.Medium
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    Text {
                        text: Qt.formatDateTime(clock.date, Settings.cfg.clock24h ? "HH:mm" : "h:mm")
                        color: Look.fg
                        font.family: Look.widgetFont
                        font.pixelSize: content.timeSize
                        font.weight: Font.DemiBold
                        font.letterSpacing: -content.timeSize * 0.02
                    }
                    Text {
                        visible: !Settings.cfg.clock24h
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: content.timeSize * 0.2
                        text: Qt.formatDateTime(clock.date, "AP")
                        color: Look.fgDim
                        font.family: Look.widgetFont
                        font.pixelSize: content.timeSize * 0.2
                        font.weight: Font.Medium
                    }
                }

                Item { Layout.preferredHeight: Math.round(content.timeSize * 0.3) }

                // password pill
                Rectangle {
                    id: field

                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 340
                    implicitHeight: 56
                    radius: height / 2
                    color: Qt.rgba(Look.surfaceHi.r, Look.surfaceHi.g, Look.surfaceHi.b, 0.8)
                    border.width: 2
                    border.color: Lock.status === "failed" ? Look.error
                        : Lock.status === "checking" ? Look.primary
                        : Lock.buffer.length > 0 ? Qt.alpha(Look.primary, 0.7)
                        : Qt.alpha(Look.outline, 0.6)

                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    transform: Translate { id: shake; x: 0 }

                    SequentialAnimation {
                        id: shakeAnim

                        NumberAnimation { target: shake; property: "x"; to: -16; duration: 55 }
                        NumberAnimation { target: shake; property: "x"; to: 14; duration: 70 }
                        NumberAnimation { target: shake; property: "x"; to: -10; duration: 70 }
                        NumberAnimation { target: shake; property: "x"; to: 6; duration: 60 }
                        NumberAnimation { target: shake; property: "x"; to: 0; duration: 50 }
                    }
                    Connections {
                        target: Lock
                        function onFailuresChanged() { shakeAnim.restart(); }
                    }

                    InkIcon {
                        id: lead

                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: Lock.status === "failed" ? "error" : "lock"
                        color: Lock.status === "failed" ? Look.error : Look.fgDim
                        pixelSize: 20
                        box: 28
                    }

                    // dots (the last 12 show; the field itself keeps the whole password)
                    Item {
                        anchors.left: lead.right
                        anchors.right: go.left
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        clip: true

                        Label {
                            anchors.centerIn: parent
                            visible: Lock.buffer.length === 0
                            text: Lock.status === "checking" ? "Checking…" : Lock.user
                            color: Look.fgDim
                            font.pixelSize: 15
                        }
                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Repeater {
                                model: Math.min(Lock.buffer.length, 12)

                                Rectangle {
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: Look.fg
                                    scale: 0

                                    Component.onCompleted: scale = 1
                                    Behavior on scale { Anim { duration: Look.dur.fast } }
                                }
                            }
                        }
                    }

                    // submit button
                    Rectangle {
                        id: go

                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        height: 40
                        radius: 20
                        color: goMouse.containsMouse && Lock.buffer.length > 0 ? Qt.lighter(Look.primary, 1.1) : Look.primary
                        opacity: Lock.buffer.length > 0 && Lock.status !== "checking" ? 1 : 0.35
                        scale: goMouse.pressed ? 0.92 : 1

                        Behavior on opacity { Anim { duration: Look.dur.fast; curve: Look.standard } }
                        Behavior on scale { Anim { duration: Look.dur.fast } }

                        InkIcon {
                            anchors.centerIn: parent
                            text: "arrow_forward"
                            color: Look.primaryFg
                            pixelSize: 20
                            box: 28
                        }
                        MouseArea {
                            id: goMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                Lock.submit();
                                scene.forceActiveFocus();
                            }
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 14
                    text: Lock.status === "failed" ? Lock.message
                        : Lock.status === "checking" ? "Checking…"
                        : Lock.message !== "" ? Lock.message
                        : "Type your password"
                    color: Lock.status === "failed" ? Look.error : Look.fgDim
                    opacity: Lock.status === "idle" && Lock.message === "" ? 0.6 : 1
                    font.pixelSize: 13
                }
            }

            // ── bottom strip: now playing + battery ──
            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 36
                spacing: 20
                opacity: scene.shown ? 1 : 0

                Behavior on opacity { Anim { duration: Look.dur.slow; curve: Look.standard } }

                RowLayout {
                    visible: !!Players.active?.trackTitle
                    spacing: 8

                    InkIcon {
                        text: "music_note"
                        color: Look.fgDim
                        pixelSize: 16
                        box: 20
                    }
                    Label {
                        Layout.maximumWidth: 320
                        text: (Players.active?.trackTitle ?? "")
                            + (Players.active?.trackArtist ? "  ·  " + Players.active.trackArtist : "")
                        color: Look.fgDim
                        font.pixelSize: 13
                    }
                }
                RowLayout {
                    visible: Battery.present
                    spacing: 6

                    InkIcon {
                        text: Battery.icon
                        color: Battery.low ? Look.error : Look.fgDim
                        pixelSize: 18
                        box: 22
                    }
                    Label {
                        text: Math.round(Battery.percent) + "%"
                        color: Battery.low ? Look.error : Look.fgDim
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
