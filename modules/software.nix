{pkgs, lib, config, ...}:
with pkgs;
with lib;
with builtins;
let
  rescueScript = writeShellApplication {
    name = "rescue";
    text = ''
      BOOTDEV="${"$"}{1}1"
      ROOTDEV="${"$"}{1}2"
      cryptsetup open "$ROOTDEV" cryptoroot

      mount -o noatime,compress=lzo,space_cache,subvol=@ /dev/disk/by-label/ROOT /mnt
      mount -o noatime,compress=lzo,space_cache,subvol=@home /dev/disk/by-label/ROOT /mnt/home
      mount -o noatime,compress=lzo,space_cache,subvol=@var /dev/disk/by-label/ROOT /mnt/var
      mount -o noatime,compress=lzo,space_cache,subvol=@pagefile /dev/disk/by-label/ROOT /mnt/.pagefiles
      mount "$BOOTDEV" /mnt/boot
    '';
  };

  unrescueScript = writeShellApplication {
    name = "unrescue";
    text = ''
      umount /mnt -R
      cryptsetup close cryptroot
    '';
  };

  gpgHelper = writeShellApplication {
    name = "gpg-helper";
    text = ''

      usage() {
        echo "Usage:"
        echo "gpg-helper command"
        echo ""
        echo "Commands:"
        echo "init - creates a GPG folder in /tmp"
        echo "mount - Mounts ventoy persistant volume and loads encrypted volume inside it"
        echo "umount - Unmounts ventoy persistant volume so it's safe to shutdown"
        echo "import - Import keys from encrypted volume after its mounted into gpg"
        echo "copy - Take a copy of gpghome before its loaded onto a yubikey"
        echo "restore - Restore gpg folder after keys have been copied to yubikey"
        echo "reset - Resets gpg"
      }

      initGPG() {
        mkdir /tmp/GPGTMP
        cat << EOF > /tmp/GPGTMP/gpg.conf
      personal-cipher-preferences AES256 AES192 AES
      personal-digest-preferences SHA512 SHA384 SHA256
      personal-compress-preferences ZLIB BZIP2 ZIP Uncompressed
      default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
      cert-digest-algo SHA512
      s2k-digest-algo SHA512
      s2k-cipher-algo AES256
      charset utf-8
      fixed-list-mode
      no-comments
      no-emit-version
      keyid-format 0xlong
      list-options show-uid-validity
      verify-options show-uid-validity
      with-fingerprint
      require-cross-certification
      no-symkey-cache
      use-agent
      throw-keyids
      EOF

        echo "pinentry-program /run/current-system/sw/bin/pinentry-qt" > /tmp/GPGTMP/gpg-agent.conf

        echo "GPG Folder setup in /tmp/GPGTMP"
        echo "Run the following: export GNUPGHOME=/tmp/GPGTMP"
      }

      if [ $# -eq 0 ]; then
        usage
        exit 0
      fi

      case $1 in
      "init")
        initGPG
      ;;
      "mount")
        sudo mkdir /data
        sudo mkdir /gpg
        sudo mount /dev/mapper/vtoy_persistent /data
        echo "Enter password for vault data when prompted"
        sudo cryptsetup open /data/vault GPGDATA
        sudo mount /dev/mapper/GPGDATA /gpg
      ;;
      "umount")
        sudo umount /gpg
        sudo cryptsetup close GPGDATA
        sudo umount /data
      ;;
      "import")
        gpg --import /gpg/keys/master.key
      ;;
      "copy")
        cp -avi /tmp/GPGTMP /tmp/GPGMASTER
      ;;
      "restore")
        rm -fr /tmp/GPGTMP
        cp -avi /tmp/GPGMASTER /tmp/GPGTMP
      ;;
      "reset")
        gpgconf --reload gpg-agent
        gpg-connect-agent "scd serialno" "learn --force" /bye
      ;;
      *)
        usage
      ;;
      esac
    '';
  };

  setupDiskScript = writeShellApplication {
    name = "setupdisk";
    text = ''
      usage() {
        echo "Setup Disk Script:"
        echo "setupdisk {vm|crypt}"
        echo ""
        echo "vm - Will setup the drive as a mbr ext4 drive for running in a VM." 
        echo "crypt - Will setup a btrfs environment running on a LUKS encrypted volume"
      }


      if [[ $# != 2 ]]; then
        usage
        exit 5
      fi

      INSTALLDEV="$2"
      BOOTDEV="${"$"}{INSTALLDEV}1"
      ROOTDEV="${"$"}{INSTALLDEV}2"

      formatCrypt() {
        echo "Before you continue please be aware this will wipe out all files on the drive $INSTALLDEV"
        read -rsp 'LUKS Password:' PASSWORD
        echo ""
        read -rsp 'Confirm Password:' PASSWORD2

        if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
          echo "Passwords didn't match!"
          exit 5
        fi

        echo "Setting up partitions"
        parted -s "$INSTALLDEV" mklabel gpt mkpart fat32 1MiB 512MiB mkpart ext2 512MiB 100%

        echo "Formating UEFI boot partition..."
        mkfs.fat -n "BOOT" -F32 "$BOOTDEV"

        echo "Setting up encrypted volume..."
        echo -n "$PASSWORD" | cryptsetup -q luksFormat "$ROOTDEV"
        cryptsetup config "$ROOTDEV" --label CRYPTROOT
        echo -n "$PASSWORD" | cryptsetup open "$ROOTDEV" cryptroot

        echo "Creating btrfs partition in encrypted storage..."
        mkfs.btrfs -L ROOT /dev/mapper/cryptroot 

        echo "Creating sub volumes"
        mount /dev/mapper/cryptroot /mnt
        btrfs su cr /mnt/@
        btrfs su cr /mnt/@home
        btrfs su cr /mnt/@var
        btrfs su cr /mnt/@pagefile
        umount /mnt
        mount -o noatime,compress=lzo,space_cache,subvol=@ /dev/disk/by-label/ROOT /mnt

        mkdir -p /mnt/{boot,home,var,.pagefiles}

        echo "Mounting file systems..."
        mount -o noatime,compress=lzo,space_cache,subvol=@home /dev/disk/by-label/ROOT /mnt/home
        mount -o noatime,compress=lzo,space_cache,subvol=@var /dev/disk/by-label/ROOT /mnt/var
        mount -o noatime,compress=lzo,space_cache,subvol=@pagefile /dev/disk/by-label/ROOT /mnt/.pagefiles
        mount "$BOOTDEV" /mnt/boot

        echo "Creating and activating pagefile..."
        touch /mnt/.pagefiles/pagefile
        chattr +C /mnt/.pagefiles/pagefile
        dd if=/dev/zero of=/mnt/.pagefiles/pagefile bs=1M count=2048
        chmod 600 /mnt/.pagefiles/pagefile
        mkswap /mnt/.pagefiles/pagefile
        swapon /mnt/.pagefiles/pagefile
      }

      formatVm() {
        # File system layout only has 1 partition.
        ROOTDEV="$BOOTDEV"

        echo "Setting up partitions"
        parted -s "$INSTALLDEV" mklabel msdos mkpart primary 1MiB 100%

        echo "Creating root partition..."
        echo -n "y" | mkfs.ext4 -L "ROOT" "$ROOTDEV"

        echo "Mounting file systems..."
        mount "$ROOTDEV" /mnt

        echo "Creating and activating pagefile..."
        mkdir -p /mnt/{boot,home,var,.pagefiles}
        touch /mnt/.pagefiles/pagefile
        dd if=/dev/zero of=/mnt/.pagefiles/pagefile bs=1M count=2048
        chmod 600 /mnt/.pagefiles/pagefile
        mkswap /mnt/.pagefiles/pagefile
        swapon /mnt/.pagefiles/pagefile
      }

      case $1 in 
      "vm")
        formatVm
        echo "All done!"
      ;;
      "crypt")
        formatCrypt
        echo "All done!"
      ;;
      *)
        usage
      ;;
      esac

    '';
  };
in {
  environment.systemPackages = with pkgs; [
    wget
    curl
    bind
    killall
    dmidecode
    neofetch
    htop
    bat
    unzip
    file
    zip
    p7zip
    strace
    ltrace
    git
    git-crypt
    hwdata
    acpi
    pciutils
    bintools
    btrfs-progs
    smartmontools
    xar
    ripgrep
    nvme-cli
    lm_sensors
    python3
    nwipe
    vim
    gnufdisk
    gcc
    gnumake
    bvi
    cryptsetup
    parted
    unrescueScript
    rescueScript
    setupDiskScript
    ntfsprogs
    gnupg
    gpgHelper
    yubikey-personalization
    yubioath-desktop
    yubikey-manager
    pinentry-qt
    veracrypt
    paperkey
  ];

  services.gnome.gnome-keyring.enable = true;
  services.pcscd.enable = true;
  programs.ssh.startAgent = false;

  services.xserver.synaptics.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryFlavor = "qt";
  };

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" "usb_storage" ];

}
