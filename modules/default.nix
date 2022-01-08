{pkgs, lib, config, modulesPath, ...}:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
  ];
}
