# /etc/nixos/configuration.nix
#
# Lenovo ThinkPad P16s Gen 1 — Intel i7-1260P + NVIDIA T550
# Hyprland (Wayland) rendering on the Intel iGPU (iris), NVIDIA available
# via PRIME render offload for the occasional GPU-heavy app.
#
# After placing this file, build with:  sudo nixos-rebuild switch

{ config, lib, pkgs, ... }:

{
  imports =
    [ ./hardware-configuration.nix
    ];

  services.xserver.enable = false;

  ##########################################################################
  # Boot
  ##########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;

  # A recent kernel helps with Alder Lake (12th gen) power/thermal handling.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  ##########################################################################
  # Networking
  ##########################################################################
  networking.hostName = "p16s";
  networking.networkmanager.enable = true;

  ##########################################################################
  # Locale / time  (adjust to taste)
  ##########################################################################
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # German keyboard layout for the console; the Wayland layout is set in
  # your Hyprland config separately.
  console.keyMap = "de";

  ##########################################################################
  # Graphics — Intel iris primary, NVIDIA via PRIME offload
  ##########################################################################
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver   # iHD VAAPI driver for Gen8+ (use this on 12th gen)
      vpl-gpu-rt           # QSV / oneVPL runtime
      libvdpau-va-gl
    ];
  };

  # Force the modern iHD VAAPI driver.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Load the NVIDIA kernel module (needed even for offload-only use).
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Wayland needs KMS modesetting on.
    modesetting.enable = true;

    # T550 (Ampere) supports the open kernel modules; they're recommended
    # for Turing+ now. If you hit issues, flip this to false.
    open = true;

    # Lets you fully power down the dGPU when not in use (saves battery).
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;   # provides the `nvidia-offload` wrapper
      };

      # PCI bus IDs for this exact laptop. Verify with `lspci`:
      #   Intel  -> 00:02.0  => "PCI:0:2:0"
      #   NVIDIA -> 01:00.0  => "PCI:1:0:0"
      # If yours differ, edit these two lines.
      intelBusId  = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  ##########################################################################
  # Fan control
  ##########################################################################
  boot.kernelModules = [ "kvm-intel" "thinkpad_acpi" ];
  boot.extraModprobeConfig = ''
    options thinkpad_acpi fan_control=1
  '';

    services.thinkfan = {
    enable = true;
    levels = [
      [ 0  0   55 ]
      [ 1  53  60 ]
      [ 2  58  65 ]
      [ 3  63  72 ]
      [ 5  70  78 ]
      [ 7  75  85 ]
      ["level full-speed"  82  255 ]
    ];
    sensors = [
      {
        type = "hwmon";
        query = "/sys/devices/platform/thinkpad_hwmon/hwmon/hwmon2/temp1_input";
        indices = [ 0 ];
      }
    ];
  };

  ##########################################################################
  # Hyprland (Wayland)
  ##########################################################################
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    # --- Wayland / Electron ---
    NIXOS_OZONE_WL = "1";          # Chromium/Electron apps use Wayland
    GTK_USE_PORTAL = "1";          # Native portal file picker in Electron apps
    QT_QPA_PLATFORM = "wayland";   # flameshot dependency
    XCURSOR_THEME = "Adwaita";

    # --- GPU: render Wayland session on Intel iGPU ---
    AQ_DRM_DEVICES = "/dev/dri/card2:/dev/dri/card1";
    # ^ If desktop renders on the wrong GPU, swap card2/card1 here.
  };

  services.power-profiles-daemon.enable = true;

  # XDG portals for screen sharing, file pickers, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  ##########################################################################
  # Login manager
  ##########################################################################
  # greetd with tuigreet is lightweight and Wayland-friendly.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
      user = "greeter";
    };
  };

  ##########################################################################
  # Audio (PipeWire)
  ##########################################################################
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  ##########################################################################
  # Power / firmware / laptop bits
  ##########################################################################
  services.fwupd.enable = true;          # firmware updates
  services.thermald.enable = true;       # Intel thermal management
  services.fprintd.enable = true;        # fingerprint reader (P16s has one)
  hardware.enableRedistributableFirmware = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  ##########################################################################
  # Users
  ##########################################################################
  users.users.user = {
    isNormalUser = true;
    description = "user";
    initialPassword = "pw";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.bash;
  };

  ##########################################################################
  # Packages
  ##########################################################################
  nixpkgs.config.allowUnfree = true;   # required for NVIDIA + Discord

  environment.systemPackages = with pkgs; [
    # core CLI
    git wget curl

    # wayland / hyprland ecosystem
    waybar          # status bar
    wofi            # launcher
    kitty           # terminal
    mako            # notifications
    hyprpaper       # wallpaper
    hyprlock        # screen locker
    wl-clipboard    # clipboard
    cliphist        # clipboard history
    nautilus        # file manager
    grim slurp      # screenshots
    brightnessctl   # backlight
    polkit_gnome    # elevated access GUI
    wlogout         # power menu
    hypridle        # idle daemon for hyprlock
    thinkfan        # fan control / thermal manager
    wtype           # key press simulator
    flameshot       # snipping tool
    nwg-displays    # GUI monitor layout manager

    # waybar modules / dependencies
    pulseaudio      # 
    python3         # required by waybar scripts
    pavucontrol     # audio GUI
    blueman         # bluetooth GUI
    peaclock        # terminal clock
    alacritty       # terminal emulator
    playerctl       # media player control
    adwaita-icon-theme  # icon package
    swaynotificationcenter  # notification center
    networkmanagerapplet   # nm-connection-editor
    nwg-look               # GTK settings (action-2-1)
    libsForQt5.qtstyleplugin-kvantum  # only if you use Qt theming
    htop            # if not already present
    hyprpicker
    pywal
    # bluez           # already present in l. 153
    # networkmanager  # already present in l. 32
    

    # swaync - dependencies
    # swaynotificationcenter
    gvfs
    # pywal
    libnotify

    # apps
    ani-cli         # anime cli
    brave           # browser
    mpv             # media player
    vscodium        # editor
    vesktop         # Discord (Wayland-native client)
    spicetify-cli   # Spotify customization CLI
    gnome-control-center  # settings GUI
    teams-for-linux # microsoft teams
    libreoffice     # Office
    claude-code     # agentic coding tool

    # dev
    devenv          # declarative development environments

    # gpu / diagnostics
    mesa-demos
    vulkan-tools
    libva-utils     # `vainfo` to verify VAAPI
    nvtopPackages.full
  ];

  fonts.packages = with pkgs; [
    pkgs.nerd-fonts.droid-sans-mono
    pkgs.nerd-fonts.caskaydia-cove 
    font-awesome
  ];

  ##########################################################################
  # Misc
  ##########################################################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # The release you first installed from. Do NOT change this on upgrades.
  system.stateVersion = "26.05";
}
