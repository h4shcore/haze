pragma Singleton
import QtQuick
import Quickshell

// System actions for the launcher: "!" lists them, and typing a clear name (lock, reboot, suspend, dnd…) surfaces
// them above the apps. Log out, reboot and shut down ask for a second Enter.
Singleton {
    id: root

    readonly property var defs: [
        { id: "lock", name: "Lock screen", glyph: "lock", keys: "lock screen secure" },
        { id: "suspend", name: "Suspend", glyph: "bedtime", keys: "sleep suspend" },
        { id: "logout", name: "Log out", glyph: "logout", keys: "logout log out sign out exit", confirm: true },
        { id: "reboot", name: "Reboot", glyph: "restart_alt", keys: "reboot restart", confirm: true },
        { id: "poweroff", name: "Shut down", glyph: "power_settings_new", keys: "shutdown shut down power off poweroff", confirm: true },
        { id: "caffeine", name: "Toggle caffeine", glyph: "coffee", keys: "caffeine keep awake idle" },
        { id: "dnd", name: "Toggle focus mode", glyph: "\uf1f6", keys: "dnd focus do not disturb mute notifications" },
        { id: "nightlight", name: "Toggle night light", glyph: "nightlight", keys: "night light blue filter gamma" },
        { id: "colorpick", name: "Pick a color", glyph: "colorize", keys: "color colour picker eyedropper" },
        { id: "screenshot", name: "Take a screenshot", glyph: "\uf030", keys: "screenshot capture screen" },
        { id: "record", name: "Record the screen", glyph: "\uf03d", keys: "record recording screencast" },
        { id: "widgets", name: "Edit desktop widgets", glyph: "widgets", keys: "widgets move edit desktop" },
        { id: "settings", name: "Haze settings", glyph: "settings", keys: "settings preferences config" }
    ]

    function state(id) {
        if (id === "caffeine") return Caffeine.active ? "On  ·  Enter to turn off" : "Off  ·  Enter to turn on";
        if (id === "dnd") return Notifs.dnd ? "On  ·  Enter to turn off" : "Off  ·  Enter to turn on";
        if (id === "nightlight") return NightLight.active ? "On  ·  Enter to turn off" : "Off  ·  Enter to turn on";
        return "System";
    }

    // strict: for plain queries (needs a clear match so apps don't get buried); loose: for "!"
    function rows(query, strict) {
        const q = (query ?? "").trim().toLowerCase();
        if (strict && q === "") return [];
        const out = [];
        for (const a of defs) {
            if (q !== "") {
                const text = (a.name + " " + a.keys).toLowerCase();
                const words = text.split(/\s+/);
                const hit = strict
                    ? (q.length >= 4 && words.some(w => w.startsWith(q))) || words.includes(q) || (q.includes(" ") && text.includes(q))
                    : text.includes(q);
                if (!hit) continue;
            }
            out.push({ id: "sys:" + a.id, kind: "sys", sys: a.id, title: a.name, subtitle: state(a.id), glyph: a.glyph, confirm: a.confirm === true });
        }
        return out;
    }

    function run(id) {
        switch (id) {
        case "lock": Lock.lock(); break;
        case "suspend": Quickshell.execDetached(["systemctl", "suspend"]); break;
        case "logout": Quickshell.execDetached(Compositor.logoutCmd); break;
        case "reboot": Quickshell.execDetached(["systemctl", "reboot"]); break;
        case "poweroff": Quickshell.execDetached(["systemctl", "poweroff"]); break;
        case "caffeine": Caffeine.toggle(); break;
        case "dnd": Notifs.dnd = !Notifs.dnd; break;
        case "nightlight": NightLight.toggle(); break;
        case "colorpick": ColorPicker.pick(); break;
        case "screenshot": Capture.start("shot", "region"); break;
        case "record": Capture.start("record", Capture.target); break;
        case "widgets": Widgets.edit(); break;
        case "settings": SettingsUi.show(); break;
        }
    }
}
