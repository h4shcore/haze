//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import qs.modules
import qs.services

ShellRoot {
    Variants {
        model: Quickshell.screens
        PerScreen {}
    }

    // qs -c haze ipc call launcher toggle | show | hide | calc | emoji | run
    IpcHandler {
        target: "launcher"

        function toggle(): void { LauncherState.toggle(); }
        function show(): void { LauncherState.show(); }
        function calc(): void {
            LauncherState.preset = "=";
            LauncherState.show();
        }
        function emoji(): void {
            LauncherState.preset = ":";
            LauncherState.show();
        }
        function run(): void {
            LauncherState.preset = ">";
            LauncherState.show();
        }
        function hide(): void { LauncherState.hide(); }
    }

    Cropper {}

    // qs -c haze ipc call power toggle
    IpcHandler {
        target: "power"

        function toggle(): void { LauncherState.toggleMode("power"); }
        function show(): void {
            LauncherState.mode = "power";
            LauncherState.open = true;
        }
        function hide(): void { LauncherState.hide(); }
    }

    // qs -c haze ipc call capture toggle | region | window | fullscreen | record | stop
    IpcHandler {
        target: "capture"

        function toggle(): void { LauncherState.toggleMode("cap"); }
        function region(): void { Capture.start("shot", "region"); }
        function window(): void { Capture.start("shot", "window"); }
        function fullscreen(): void { Capture.start("shot", "screen"); }
        function record(): void { Capture.start("record", Capture.target); }
        function stop(): void { Capture.stop(); }
    }

    // qs -c haze ipc call settings toggle
    IpcHandler {
        target: "settings"

        function toggle(): void { SettingsUi.toggle(); }
        function show(): void { SettingsUi.show(); }
        function hide(): void { SettingsUi.hide(); }
    }

    // qs -c haze ipc call widgets edit
    IpcHandler {
        target: "widgets"

        function edit(): void { Widgets.edit(); }
        function done(): void { Widgets.done(); }
        function toggle(): void { Widgets.toggle(); }
    }

    // qs -c haze ipc call todo toggle
    IpcHandler {
        target: "todo"

        function toggle(): void { Todo.toggle(); }
        function show(): void { Todo.show(); }
        function hide(): void { Todo.hide(); }
    }

    // qs -c haze ipc call clipboard toggle
    IpcHandler {
        target: "clipboard"

        function toggle(): void { LauncherState.toggleMode("clip"); }
        function show(): void {
            LauncherState.mode = "clip";
            LauncherState.open = true;
        }
        function hide(): void { LauncherState.hide(); }
    }

    // qs -c haze ipc call wallpaper toggle
    IpcHandler {
        target: "wallpaper"

        function toggle(): void { LauncherState.toggleMode("wall"); }
        function show(): void {
            LauncherState.mode = "wall";
            LauncherState.open = true;
        }
        function hide(): void { LauncherState.hide(); }
    }
}
