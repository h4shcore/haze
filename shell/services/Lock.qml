pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.common

// Session lock state + password check (modules/LockScreen.qml draws it).
//
// Locks on: `haze ipc call lock lock`, `loginctl lock-session` (the power menu uses this),
// suspend (logind PrepareForSleep) and idle (Settings > Lock). Caffeine pauses the idle lock.
//
// There is deliberately no IPC call to unlock: the only way out is the password (PAM).
// The password lives in `buffer` while you type it and in `pending` for the moment it takes
// PAM to ask for it, then it is cleared.
Singleton {
    id: root

    property bool locked: false
    property string buffer: ""          // what has been typed so far
    property string status: "idle"      // idle | checking | failed
    property string message: ""         // "Wrong password", or an info line from PAM
    property int failures: 0            // bumps on every wrong attempt (the UI shakes on change)
    property string pending: ""         // password handed to PAM on its next prompt

    readonly property string user: Quickshell.env("USER")

    function lock() {
        if (locked) return;
        clear();
        status = "idle";
        message = "";
        locked = true;
    }

    function unlock() {
        locked = false;
        clear();
        pending = "";
        status = "idle";
        message = "";
    }

    function clear() { buffer = ""; }

    function type(text) {
        if (status === "checking") return;
        if (status === "failed") { status = "idle"; message = ""; }
        if (buffer.length < 256) buffer += text;
    }

    function backspace(all) {
        if (status === "checking") return;
        if (status === "failed") { status = "idle"; message = ""; }
        buffer = all ? "" : buffer.slice(0, -1);
    }

    function submit() {
        if (!locked || status === "checking" || buffer === "") return;
        pending = buffer;
        buffer = "";
        status = "checking";
        message = "";
        if (pam.active) pam.abort();
        pam.start();
    }

    function fail(text) {
        pending = "";
        buffer = "";
        message = text;
        status = "failed";
        failures++;
    }

    // turn the monitors off (they wake on the first key press or mouse move)
    function screenOff() {
        if (Compositor.isHypr)
            Quickshell.execDetached(Compositor.hyprDispatchCmd("hl.dsp.dpms({ action = \"off\" })", "dpms off"));
        else
            Compositor.action(["power-off-monitors"]);
    }

    // ── password check ──
    // Settings > Lock > PAM service. "login" exists on most distros. On NixOS you can add
    // `security.pam.services.haze = {};` to your system config and set the service to "haze".
    PamContext {
        id: pam
        config: Settings.cfg.lockPam

        onPamMessage: {
            if (responseRequired) {
                respond(root.pending);
                root.pending = "";
            } else if (message !== "") {
                root.message = message;
            }
        }
        onCompleted: result => {
            if (result === PamResult.Success) root.unlock();
            else root.fail(result === PamResult.MaxTries ? "Too many attempts" : "Wrong password");
        }
        onError: root.fail("Couldn't check the password")
    }

    // ── lock after being idle ──
    IdleMonitor {
        enabled: Settings.cfg.lockOnIdle && !root.locked && !Caffeine.active
        timeout: Settings.cfg.lockIdleMinutes * 60
        onIsIdleChanged: if (isIdle) root.lock()
    }

    // ── screen off a while after locking ──
    IdleMonitor {
        enabled: Settings.cfg.lockScreenOff && root.locked
        timeout: Settings.cfg.lockScreenOffSeconds
        onIsIdleChanged: if (isIdle) root.screenOff()
    }

    // ── logind: `loginctl lock-session` and suspend ──
    // Needs dbus-monitor (the Nix package brings it).
    Process {
        id: logind

        // D-Bus object path of this session (systemd escapes a leading digit as _3x: "2" -> "_32")
        readonly property string sessionId: Quickshell.env("XDG_SESSION_ID")
        readonly property string sessionPath: sessionId === "" ? ""
            : "/org/freedesktop/login1/session/" + (/^[0-9]/.test(sessionId)
                ? "_" + sessionId.charCodeAt(0).toString(16) + sessionId.slice(1) : sessionId)

        property bool sleepNext: false

        running: true
        command: [
            "dbus-monitor", "--system",
            "type='signal',interface='org.freedesktop.login1.Session',member='Lock'",
            "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"
        ]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("member=Lock")) {
                    if (logind.sessionPath === "" || line.includes("path=" + logind.sessionPath + ";")) root.lock();
                } else if (line.includes("member=PrepareForSleep")) {
                    logind.sleepNext = true;
                } else if (logind.sleepNext && line.includes("boolean")) {
                    logind.sleepNext = false;
                    if (line.includes("true")) root.lock();
                }
            }
        }
    }
}
