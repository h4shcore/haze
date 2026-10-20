pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── colors: defaults below, overridden live by ~/.config/quickshell/colors.json (matugen) ──
    readonly property color surface: c.surface
    readonly property color surfaceHi: c.surfaceHi
    readonly property color surfaceHiest: c.surfaceHiest
    readonly property color fg: c.fg
    readonly property color fgDim: c.fgDim
    // Settings > Appearance > Accent color: a valid "#rrggbb" replaces the wallpaper-derived accent
    readonly property bool accentSet: /^#[0-9a-fA-F]{6}$/.test(Settings.cfg.accent)
    readonly property color primary: accentSet ? Settings.cfg.accent : c.primary
    readonly property color primaryFg: accentSet ? (Qt.color(Settings.cfg.accent).hslLightness > 0.6 ? "#1b1b1f" : "#ffffff") : c.primaryFg
    readonly property color secondaryContainer: c.secondaryContainer
    readonly property color error: c.error
    readonly property color outline: c.outline

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        adapter: JsonAdapter {
            id: c
            property string surface: "#141318"
            property string surfaceHi: "#2b292f"
            property string surfaceHiest: "#36343a"
            property string fg: "#e6e0e9"
            property string fgDim: "#938f99"
            property string primary: "#d0bcff"
            property string primaryFg: "#381e72"
            property string secondaryContainer: "#4a4458"
            property string error: "#f2b8b5"
            property string outline: "#49454f"
        }
    }

    // ── sizing ──
    readonly property int pillHeight: Settings.cfg.barHeight       // collapsed notch / top dock height (Settings)
    readonly property int gap: 8
    readonly property int pad: 16
    readonly property int panelRadius: Settings.cfg.panelRadius    // expanded notch corners (Settings)
    readonly property int border: Settings.cfg.borderThickness     // screen border thickness (Settings)
    readonly property int borderRadius: Settings.cfg.frameRadius   // inner corner radius of the screen border (Settings)
    readonly property int earRadius: Settings.cfg.earRadius        // concave corners where the notch meets the top border (Settings)
    readonly property int notchRadius: Settings.cfg.notchRadius    // notch bottom corner radius (Settings)
    readonly property int reserveTop: pillHeight   // space tiled windows leave at the top (set to pillHeight so the notch never overlaps them)

    // ── fonts (Nerd Font gives the icon glyphs too) ──
    readonly property string font: Settings.cfg.fontFamily   // Settings > Appearance > Font

    // Desktop widgets use a macOS-style font: your pick if it's installed, else the first installed of
    // SF Pro (the real thing), Inter (closest free match) and Helvetica Neue, else the shell font.
    // Empty setting = shell font.
    readonly property string widgetFont: {
        if (Settings.cfg.widgetFont === "") return font;
        const have = Qt.fontFamilies();
        const pick = [Settings.cfg.widgetFont, "SF Pro Display", "SF Pro Text", "Inter", "Helvetica Neue"]
            .find(f => have.indexOf(f) >= 0);
        return pick ?? font;
    }

    // ── motion (curves are the M3-expressive ones caelestia uses) ──
    readonly property var spring: [0.38, 1.21, 0.22, 1.0, 1, 1]
    readonly property var smooth: [0.16, 1, 0.3, 1, 1, 1]   // soft expo-out: fast start, long glide, no overshoot
    readonly property var standard: [0.2, 0, 0, 1, 1, 1]
    readonly property var emphasized: [0.05, 0, 0.133, 0.06, 0.166, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]
    readonly property var dur: ({ fast: 180, normal: 400, slow: 650 })
}
