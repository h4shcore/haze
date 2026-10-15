{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  # tools Haze shells out to (put on PATH *after* your system's own, so yours win)
  grim,
  wl-clipboard,
  cliphist,
  wl-screenrec,
  wtype,
  matugen,
  brightnessctl,
  libnotify,
  xdg-utils,
  procps,
  coreutils,
}:

let
  runtimeDeps = [
    grim # screenshots
    wl-clipboard # wl-copy / wl-paste
    cliphist # clipboard history
    wl-screenrec # screen recording
    wtype # paste from the clipboard dock
    matugen # colors from the wallpaper
    brightnessctl # brightness slider
    libnotify # capture notifications
    xdg-utils # open screenshots / recordings
    procps # pgrep
    coreutils
  ];
in
stdenvNoCC.mkDerivation {
  pname = "haze";
  version = "0.1.0";

  src = ../shell;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  # `haze` starts the shell; `haze ipc call launcher toggle` controls it (same as `qs -c haze ...`)
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/haze $out/bin
    cp -r . $out/share/haze/shell

    makeWrapper ${lib.getExe quickshell} $out/bin/haze \
      --add-flags "-p $out/share/haze/shell" \
      --suffix PATH : ${lib.makeBinPath runtimeDeps}

    runHook postInstall
  '';

  passthru = {
    inherit runtimeDeps;
  };

  meta = {
    homepage = "https://github.com/h4shcore/haze";
    description = "A Quickshell shell for Niri";
    license = lib.licenses.mit;
    mainProgram = "haze";
    platforms = lib.platforms.linux;
  };
}
