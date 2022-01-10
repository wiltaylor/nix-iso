{pkgs, config, lib, ...}:
{
  users.users.nixos= {
    name = "nixos";
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    uid = 1000;
    initialPassword = "nixos";
  };

  security.sudo.enable = true;
  security.sudo.wheelNeedsPassword = false;

  system.activationScripts = {
    bashSetup.text = ''

      mkdir -p /home/nixos
      cat << EOF > /home/nixos/.bashrc
      neofetch
      echo "Welcome to Wil's NixOS installer."
      echo "Use network manager to connect to wifi:"
      echo 'nmcli dev wifi con "NetworkSID" password "YourPassword"'
      echo "nixos-help - Will open the nixos manual"
      echo ""
      echo "Extra setup commands:"
      echo "rescue {device} - Mounts a encrypted system's drives using my btrfs layout."
      echo "unrescue - Umounts an encrypted system"
      echo "setupdisk {vm|crypt} {device} - Sets up a disk ready for nixos install (only use if you want my layout)."
      echo ""
      EOF

      chown 1000:1000 /home/nixos -R

    '';
  };
}
