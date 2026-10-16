import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Desktop widgets: a transparent surface above the wallpaper and below your windows.
// Only the widgets catch clicks. Edit mode (Settings → Widgets, or `ipc call widgets edit`) lifts the
// layer above windows so you can drag them (they snap to a grid); Done / Esc puts it back.
PanelWindow {
    id: win

    readonly property bool focusedHere: (Compositor.focusedOutput || screen.name) === screen.name
    readonly property bool any: Settings.cfg.widgetClock || Settings.cfg.widgetMedia || Settings.cfg.widgetSysmon
        || Settings.cfg.widgetCalendar || Settings.cfg.widgetTodo || Settings.cfg.widgetWeather

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
        Region { item: calW.visible ? calW : null }
        Region { item: todoW.visible ? todoW : null }
        Region { item: weatherW.visible ? weatherW : null }
        Region { item: editBar.visible ? editBar : null }
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Widgets.done()
    }

    // ── edit mode backdrop: dim + grid dots (visual only, not in the input mask) ──
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: Widgets.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { duration: 250; curve: Look.standard } }
    }

    Canvas {
        id: grid

        anchors.fill: parent
        opacity: Widgets.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Anim { duration: 250; curve: Look.standard } }

        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = Qt.alpha(Look.fg, 0.28);
            const g = Widgets.grid;
            for (let x = g; x < width; x += g)
                for (let y = g; y < height; y += g) {
                    ctx.beginPath();
                    ctx.arc(x, y, 1.5, 0, Math.PI * 2);
                    ctx.fill();
                }
        }
    }

    // ── clock: big, light, minimal ──
    DesktopWidget {
        id: clockW
        name: "Clock"
        surface: win.contentItem
        defaultX: 80
        defaultY: 120
        width: clockCol.implicitWidth
        height: clockCol.implicitHeight

        SystemClock {
            id: clock
            precision: Settings.cfg.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
        }

        ColumnLayout {
            id: clockCol
            spacing: 4

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.35
                shadowBlur: 0.8
                shadowVerticalOffset: 3
            }

            RowLayout {
                spacing: 2

                Label {
                    text: Qt.formatDateTime(clock.date, Settings.cfg.clock24h ? "HH" : "h")
                    font.pixelSize: 124
                    font.weight: Font.Light
                }
                Label {
                    Layout.bottomMargin: 10
                    text: ":"
                    font.pixelSize: 124
                    font.weight: Font.Light
                    color: Look.primary

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: clockW.visible
                        NumberAnimation { to: 0.35; duration: 1200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1200; easing.type: Easing.InOutSine }
                    }
                }
                Label {
                    text: Qt.formatDateTime(clock.date, "mm")
                    font.pixelSize: 124
                    font.weight: Font.Light
                }
                Label {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 26
                    Layout.leftMargin: 6
                    visible: !Settings.cfg.clock24h
                    text: Qt.formatDateTime(clock.date, "AP")
                    font.pixelSize: 22
                    color: Look.fgDim
                }
            }

            Label {
                Layout.leftMargin: 6
                text: Qt.formatDateTime(clock.date, "dddd  ·  d MMMM").toUpperCase()
                font.pixelSize: 14
                font.letterSpacing: 4
                color: Look.fgDim
            }
        }
    }

    // ── now playing ──
    DesktopWidget {
        id: mediaW
        name: "Media"
        surface: win.contentItem
        defaultX: 80
        defaultY: 320
        showWhen: Players.active !== null
        width: media.implicitWidth
        height: media.implicitHeight

        WidgetMedia {
            id: media
        }
    }

    // ── system monitor ──
    DesktopWidget {
        id: sysW
        name: "Sysmon"
        surface: win.contentItem
        defaultX: 560
        defaultY: 320
        width: 280
        height: 150

        SysMonRings {
            anchors.fill: parent
        }
    }

    // ── weather ──
    DesktopWidget {
        id: weatherW
        name: "Weather"
        surface: win.contentItem
        defaultX: win.width - width - 80
        defaultY: 120
        width: weather.implicitWidth
        height: weather.implicitHeight

        WidgetWeather {
            id: weather
        }
    }

    // ── calendar ──
    DesktopWidget {
        id: calW
        name: "Calendar"
        surface: win.contentItem
        defaultX: win.width - width - 80
        defaultY: 360
        width: cal.implicitWidth
        height: cal.implicitHeight

        WidgetCalendar {
            id: cal
        }
    }

    // ── todo ──
    DesktopWidget {
        id: todoW
        name: "Todo"
        surface: win.contentItem
        defaultX: 80
        defaultY: win.height - height - 80
        width: todo.implicitWidth
        height: todo.implicitHeight

        WidgetTodo {
            id: todo
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
                text: "Drag to move · snaps to the grid · double-click a widget to reset"
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
