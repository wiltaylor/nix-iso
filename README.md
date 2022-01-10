# NixOS Installers
This flake can be used to generate custom nixos installers. Feel free to use for your own purposes (fork, copy etc).

## Images:

### i3 Image
ISO that quickly boots into an i3 environment with a shell window open ready to install nixos.

Features:
- Firefox 
- Common command line tools
- Rescue scripts for my LUKS btrfs encrypted layout (Recommend reading the scripts before using them).
- Disk setup script for applying my LUKS btrfs encrypted layout (Again read the scripts before using them).
- Nix with flakes and experimental commands enabled.


## How to build ISO
```shell
nix build github:wiltaylor/nix-iso#iso.x86_64-linux.i3
```
