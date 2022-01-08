{
  description = "This flake has a number of nix ISO files that can be used to deploy nixos.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let

    lib = import ./lib;
    system = "x86_64-linux";

    allPkgs = lib.mkPkgs { inherit nixpkgs; };

    mkIso = {system, cfg ? {}, ...}: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {};

      modules = [
        {
          imports = [ ./modules ];
          nixpkgs.pkgs = allPkgs."${system}";
        }

        cfg
      ];
    };
  in {
    iso = lib.withDefaultSystems (sys: {
      i3 = (mkIso { system = sys; }).config.system.build.isoImage;
    });
  };
}
