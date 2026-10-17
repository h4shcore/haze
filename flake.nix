{
  description = "Haze: a Quickshell shell for Niri and Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Haze needs Quickshell 0.3 or newer
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      quickshell,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        system: pkgs: rec {
          haze = pkgs.callPackage ./nix/package.nix {
            quickshell = quickshell.packages.${system}.default;
          };
          default = haze;
        }
      );

      # programs.haze.enable = true;
      homeModules.default = import ./nix/hm-module.nix self;
      homeManagerModules.default = self.homeModules.default;

      overlays.default = final: _prev: {
        haze = self.packages.${final.stdenv.hostPlatform.system}.default;
      };

      # nix develop: Quickshell + every tool Haze shells out to, then `qs -p shell`
      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [ quickshell.packages.${system}.default ] ++ self.packages.${system}.default.runtimeDeps;
            shellHook = ''
              echo "haze dev shell: run the shell from this repo with:  qs -p shell"
            '';
          };
        }
      );
    };
}
