pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Weather from wttr.in (no key needed). Location: Settings → Widgets, empty = guessed from your IP.
// Fetches only while a weather widget is visible, then every 30 minutes.
Singleton {
    id: root

    property bool ok: false
    property string city: ""
    property string desc: ""
    property real tempC: 0
    property real tempF: 0
    property real feelsC: 0
    property real feelsF: 0
    property int humidity: 0
    property var days: []        // [{ name, maxC, minC, maxF, minF }]

    readonly property bool fahrenheit: Settings.cfg.weatherFahrenheit
    readonly property real temp: fahrenheit ? tempF : tempC
    readonly property real feels: fahrenheit ? feelsF : feelsC

    property int viewers: 0
    function hold() { viewers++; }
    function release() { viewers = Math.max(0, viewers - 1); }

    // Material symbol names (also mapped to Nerd Font glyphs in Icons.qml)
    readonly property string glyph: {
        const d = desc.toLowerCase();
        if (/thunder/.test(d)) return "thunderstorm";
        if (/snow|sleet|ice|blizzard|freezing/.test(d)) return "ac_unit";
        if (/rain|drizzle|shower/.test(d)) return "rainy";
        if (/sun|clear/.test(d)) return "wb_sunny";
        return "cloud";
    }

    function refresh() { if (!proc.running) proc.running = true; }

    // refetch when the location setting changes
    readonly property string location: Settings.cfg.weatherLocation
    onLocationChanged: if (viewers > 0) refresh()

    Process {
        id: proc
        command: ["curl", "-fsS", "--max-time", "12",
            "https://wttr.in/" + encodeURIComponent(Settings.cfg.weatherLocation) + "?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const c = j.current_condition[0];
                    root.tempC = Number(c.temp_C);
                    root.tempF = Number(c.temp_F);
                    root.feelsC = Number(c.FeelsLikeC);
                    root.feelsF = Number(c.FeelsLikeF);
                    root.humidity = Number(c.humidity);
                    root.desc = c.weatherDesc[0].value;
                    root.city = j.nearest_area?.[0]?.areaName?.[0]?.value ?? "";
                    root.days = j.weather.slice(0, 3).map(d => ({
                        name: Qt.formatDate(new Date(d.date + "T12:00:00"), "ddd").toUpperCase(),
                        maxC: Number(d.maxtempC), minC: Number(d.mintempC),
                        maxF: Number(d.maxtempF), minF: Number(d.mintempF)
                    }));
                    root.ok = true;
                } catch (err) {
                    root.ok = false;
                }
            }
        }
    }

    Timer {
        interval: 30 * 60 * 1000
        running: root.viewers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
