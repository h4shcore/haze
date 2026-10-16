import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

// Desktop widgets, macOS style: solid rounded cards in small / medium / large sizes on a transparent
// surface above the wallpaper and below your windows. Only the cards catch clicks.
// Edit mode (Settings → Widgets, or `ipc call widgets edit`) lifts the layer above windows, dims the
// screen and shows a grid; drag a card and it snaps. Done / Esc puts it back.
PanelWindow {
    id: win

    readonly property bool focusedHere: (Compositor.focusedOutput || screen.name) === screen.name
    readonly property bool any: Settings.cfg.widgetClock || Settings.cfg.widgetMedia
        || Settings.cfg.widgetSysmon || Settings.cfg.widgetTodo

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
        Region { item: todoW.visible ? todoW : null }
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
            ctx.fillStyle = Qt.alpha(Look.fg, 0.22);
            const g = Widgets.grid;
            for (let x = g; x < width; x += g)
                for (let y = g; y < height; y += g)
                    ctx.fillRect(x - 0.75, y - 0.75, 1.5, 1.5);
        }
    }

    // ── clock (small: time only · medium: time + date) ──
    DesktopWidget {
        id: clockW
        name: "Clock"
        size: Settings.cfg.widgetClockSize === "small" ? "small" : "medium"
        surface: win.contentItem
        defaultX: 60
        defaultY: 100

        WidgetClock {
            anchors.fill: parent
            anchors.margins: clockW.size === "small" ? 8 : 18
            compact: clockW.size === "small"
        }
    }

    // ── now playing (small: album only · medium: full player; skeleton while idle unless hidden in Settings) ──
    DesktopWidget {
        id: mediaW
        name: "Media"
        size: Settings.cfg.widgetMediaSize === "small" ? "small" : "medium"
        surface: win.contentItem
        defaultX: 60
        defaultY: 280
        showWhen: !Settings.cfg.widgetMediaHideIdle || Players.active !== null

        WidgetMedia {
            anchors.fill: parent
            anchors.margins: mediaW.size === "small" ? 1 : 18   // small: art fills the card, inside its border
            compact: mediaW.size === "small"
        }
    }

    // ── system monitor (small) ──
    DesktopWidget {
        id: sysW
        name: "Sysmon"
        size: "small"
        surface: win.contentItem
        defaultX: 420
        defaultY: 100

        SysMonRings {
            anchors.fill: parent
            anchors.margins: 18
        }
    }

    // ── todo (large) ──
    DesktopWidget {
        id: todoW
        name: "Todo"
        size: "large"
        surface: win.contentItem
        defaultX: Math.round((win.width - width - 60) / 20) * 20
        defaultY: 100

        WidgetTodo {
            anchors.fill: parent
            anchors.margins: 20
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
