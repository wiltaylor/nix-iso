{ pkgs, lib, config, ...}:
with pkgs;
with lib;
with builtins;
let
  cfg = config.iso;

  i3cfg = pkgs.writeText "i3config" ''
    set $mod Mod4
    font pango:DejaVu Sans Mono 8
    floating_modifier $mod
    #exec "xrandr --output Virtual-1 --mode 1920x1080"
    exec "${pkgs.alacritty}/bin/alacritty"
    bindsym $mod+Return exec ${pkgs.alacritty}/bin/alacritty
    bindsym $mod+Shift+q kill
    bindsym $mod+d exec dmenu_run
    # change focus
    bindsym $mod+j focus left
    bindsym $mod+k focus down
    bindsym $mod+l focus up
    bindsym $mod+semicolon focus right
    # alternatively, you can use the cursor keys:
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right
    # move focused window
    bindsym $mod+Shift+j move left
    bindsym $mod+Shift+k move down
    bindsym $mod+Shift+l move up
    bindsym $mod+Shift+semicolon move right
    # alternatively, you can use the cursor keys:
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right
    # split in horizontal orientation
    bindsym $mod+h split h
    # split in vertical orientation
    bindsym $mod+v split v
    # enter fullscreen mode for the focused container
    bindsym $mod+f fullscreen
    # change container layout (stacked, tabbed, toggle split)
    bindsym $mod+s layout stacking
    bindsym $mod+w layout tabbed
    bindsym $mod+e layout toggle split
    # toggle tiling / floating
    bindsym $mod+Shift+space floating toggle
    # change focus between tiling / floating windows
    bindsym $mod+space focus mode_toggle
    # focus the parent container
    bindsym $mod+a focus parent
    # focus the child container
    #bindsym $mod+d focus child
    smart_gaps on
    new_window pixel 1
    gaps inner 20
    gaps outer -4
  '';
in {
  options.iso = {
    wm = mkOption {
      type = types.enum ["i3" "sway" "none"];
      default = "none";
      description = "Window manager to use on the iso";
    };
  };

  config = mkIf (cfg.wm != "none") {
    services.xserver = {
      enable = true;

      desktopManager = {
        xterm.enable = false;
      };

      displayManager = {
        autoLogin = {
          user = "nixos";
          enable = true;
        };

        gdm = {
          enable = true; 
        };
      }; 


      windowManager.i3 = mkIf (cfg.wm == "i3") {
        enable = true;
        package = pkgs.i3-gaps;
        configFile = i3cfg;

        extraPackages = with pkgs; [
          dmenu
          alacritty
          firefox
        ];
      };
    };
  };
}
