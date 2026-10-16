import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Desktop widgets: a transparent surface above the wallpaper and below your windows.
// Only the widgets catch clicks. Edit mode (Settings → Widgets, or `ipc call widgets edit`) lifts the
// layer above windows so you can drag them; Done / Esc puts it back.
PanelWindow {
    id: win

    readonly property bool focusedHere: (Compositor.focusedOutput || screen.name) === screen.name
    readonly property bool any: Settings.cfg.widgetClock || Settings.cfg.widgetMedia || Settings.cfg.widgetSysmon

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    visible: any
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "haze-widgets"
    WlrLayershell.layer: Widgets.editing ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: Widgets.editing && focusedHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: clockW.visible ? clockW : null
        Region { item: mediaW.visible ? mediaW : null }
        Region { item: sysW.visible ? sysW : null }
        Region { item: editBar.visible ? editBar : null }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Widgets.done()
    }

    // ── clock: big time + date straight on the wallpaper ──
    DesktopWidget {
        id: clockW
        name: "Clock"
        surface: win.contentItem
        defaultX: 90
        defaultY: 110
        width: clockCol.implicitWidth
        height: clockCol.implicitHeight

        SystemClock {
            id: clock
            precision: Settings.cfg.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
        }

        ColumnLayout {
            id: clockCol
            spacing: -6

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.45
                shadowBlur: 0.7
                shadowVerticalOffset: 4
            }

            Label {
                text: Qt.formatDateTime(clock.date, Settings.cfg.clock24h
                    ? (Settings.cfg.clockSeconds ? "HH:mm:ss" : "HH:mm")
                    : (Settings.cfg.clockSeconds ? "h:mm:ss AP" : "h:mm AP"))
                font.pixelSize: 96
                font.bold: true
            }
            Label {
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                font.pixelSize: 22
                color: Look.fgDim
            }
        }
    }

    // ── now playing: the control center's media card ──
    DesktopWidget {
        id: mediaW
        name: "Media"
        surface: win.contentItem
        defaultX: 90
        defaultY: 330
        showWhen: Players.active !== null
        width: 340
        height: media.implicitHeight

        MediaCard {
            id: media
            width: parent.width
        }
    }

    // ── system monitor ──
    DesktopWidget {
        id: sysW
        name: "Sysmon"
        surface: win.contentItem
        defaultX: 460
        defaultY: 110
        width: 150
        height: 210

        SysMonCard {
            anchors.fill: parent
            shown: true
        }
    }

    // ── edit mode bar ──
    Rectangle {
        id: editBar

        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        width: barRow.implicitWidth + 28
        height: 48
        radius: 24
        color: Look.surface
        border.width: 1
        border.color: Qt.alpha(Look.outline, 0.7)
        visible: Widgets.editing && win.focusedHere

        RowLayout {
            id: barRow
            anchors.centerIn: parent
            spacing: 14

            Label {
                text: "Drag widgets to move them · double-click one to reset"
                font.pixelSize: 12
                color: Look.fgDim
            }
            Rectangle {
                Layout.preferredWidth: doneLabel.implicitWidth + 28
                Layout.preferredHeight: 32
                radius: 16
                color: Look.primary

                Label {
                    id: doneLabel
                    anchors.centerIn: parent
                    text: "Done"
                    font.bold: true
                    font.pixelSize: 13
                    color: Look.primaryFg
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Widgets.done()
                }
            }
        }
    }
}
