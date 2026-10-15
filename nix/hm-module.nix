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
    enable = lib.mkEnableOption "Haze, a Quickshell shell for Niri";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "haze.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "The Haze package to use.";
    };

    installFonts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install Maple Mono NF and Material Symbols, the fonts Haze is designed around.";
    };

    systemd.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run Haze as a systemd user service tied to graphical-session.target.
        Leave this off if you start it from your compositor instead
        (for example `spawn-at-startup "haze"` in Niri).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
    ]
    ++ lib.optionals cfg.installFonts [
      pkgs.maple-mono.NF
      pkgs.material-symbols
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
