self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.haze;
in
{
  options.programs.haze = {
    enable = lib.mkEnableOption "Haze, a Quickshell shell for Niri and Hyprland";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "haze.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "The Haze package to use.";
    };

    installFonts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Rubik, Inter, Material Symbols and the Nerd Font symbols (icon fallback), the fonts Haze is designed around.";
    };

    systemd.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run Haze as a systemd user service tied to graphical-session.target.
        Leave this off if you start it from your compositor instead
        (for example `spawn-at-startup "haze"` in Niri or `hl.exec_cmd("haze")` in hyprland.lua).
        Under Hyprland the service needs HYPRLAND_INSTANCE_SIGNATURE in the user manager's
        environment, which `dbus-update-activation-environment --systemd --all` provides.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
    ]
    ++ lib.optionals cfg.installFonts [
      pkgs.rubik
      pkgs.inter # closest free match to the macOS font, used by the desktop widgets
      pkgs.material-symbols
      pkgs.nerd-fonts.symbols-only
    ];

    fonts.fontconfig.enable = lib.mkIf cfg.installFonts true;

    systemd.user.services.haze = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "Haze shell";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
