# /etc/nixos/configuration.nix
#
# Lenovo ThinkPad P16s Gen 1 — Intel i7-1260P + NVIDIA T550
# Hyprland (Wayland) rendering on the Intel iGPU (iris), NVIDIA available
# via PRIME render offload for the occasional GPU-heavy app.
#
# After placing this file, build with:  sudo nixos-rebuild switch

{ config, lib, pkgs, ... }:

let
  # "bsod" GRUB theme — https://github.com/ademmenh/bsod
  # Packaged manually as a derivation because upstream ships a Makefile
  # that pokes at /etc/default/grub and calls grub2-mkconfig directly,
  # which doesn't fit NixOS's declarative boot.loader.grub.theme option.
  # The theme's files live in a "bsod/" subfolder of the repo, so the
  # installPhase copies just that subfolder's contents to $out.
  bsodGrubTheme = pkgs.stdenvNoCC.mkDerivation {
    pname = "bsod-grub-theme";
    version = "f8d9456";
    src = pkgs.fetchFromGitHub {
      owner = "ademmenh";
      repo = "bsod";
      rev = "f8d9456d0fe244e208b5858f7883cac44481efc1";
      hash = "sha256-Fj9CS+29S6cq6LE6AmjKn/UEReT551DlcJBZCbzeIqA=";
    };
    installPhase = ''
      mkdir -p $out
      cp -r $src/bsod/* $out/
    '';
  };
in
{
  imports =
    [ ./hardware-configuration.nix
    ];

  services.xserver.enable = false;

  ##########################################################################
  # Boot
  ##########################################################################
  # Switched from systemd-boot to GRUB so the "bsod" theme (a GRUB theme)
  # has something to render. systemd-boot has no equivalent theming.
  boot.loader.systemd-boot.enable = false;

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";        # required for pure-EFI installs (no MBR write)
    useOSProber = true;     # flip to true if you dual-boot another OS
    configurationLimit = 10;
    theme = bsodGrubTheme;
    gfxmodeEfi = "1920x1080"; # matches the theme's default background res
  };

  # A recent kernel helps with Alder Lake (12th gen) power/thermal handling.
  boot.kernelPackages = pkgs.linuxPackages_7_1;

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
      intelBusId  = "PCI:0:2:0";
      nvidiaBusId = "PCI:3:0:0";
    };
  };

  ##########################################################################
  # Fan control
  ##########################################################################
  
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

    # --- GPU: render the Wayland session on the Intel iGPU ---
    LIBVA_DRIVER_NAME = "iHD";  
    AQ_DRM_DEVICES = "/dev/dri/by-path/pci-0000:00:02.0-card";

    # --- Wayland / Electron ---
    NIXOS_OZONE_WL = "1";          # Chromium/Electron apps use Wayland
    QT_QPA_PLATFORM = "wayland";   # flameshot dependency
    XCURSOR_THEME = "Adwaita";

  };

  services.power-profiles-daemon.enable = true;

  # XDG portals for screen sharing, file pickers, etc.
xdg.portal = {
  enable = true;
  extraPortals = [
    pkgs.xdg-desktop-portal-gtk
    pkgs.xdg-desktop-portal-hyprland   # screen sharing + screen picker
  ];
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
  services.fprintd.enable = false;        # fingerprint reader (not wired yet )
  hardware.enableRedistributableFirmware = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  ##########################################################################
  # Embedded development — Raspberry Pi RP2xxx / SparkFun boards
  ##########################################################################
  # Lets the logged-in user flash boards and open the serial console without
  # being a member of `dialout`. Two vendor IDs are needed because the board
  # changes identity depending on what it is running:
  #   2e8a = Raspberry Pi  (RP2350 BOOTSEL mass storage, stock firmware)
  #   1b4f = SparkFun      (Thing Plus RP2350 running an Arduino sketch)
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="2e8a", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="1b4f", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="2e8a", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1b4f", MODE="0666", TAG+="uaccess"
  '';

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

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib   # libstdc++, libgcc_s — the most common culprits
      zlib
      openssl
      curl
      icu
      libunwind
    ];
  };

  environment.systemPackages = with pkgs; [
    # core CLI
    git wget curl

    # QuickShell environment
    quickshell        # the QML shell runtime
    matugen           # Material You palette generation (required)
    awww              # wallpaper daemon with an IPC Brain_Shell drives
    imagemagick       # image processing for wallpaper/colour work
    wf-recorder       # screen recording
    cava              # audio visualiser widget
    lm_sensors        # temperature readouts
    hyprsunset        # colour temperature
    hyprpolkitagent   # replaces polkit-gnome




    # wayland / hyprland ecosystem
    kitty           # terminal
    hyprlock        # screen locker
    wl-clipboard    # clipboard
    cliphist        # clipboard history
    nautilus        # file manager
    grim slurp      # screenshots
    brightnessctl   # backlight
    wlogout         # power menu
    hypridle        # idle daemon for hyprlock
    wtype           # key press simulator
    flameshot       # snipping tool
    nwg-displays    # GUI monitor layout manager

    # waybar modules / dependencies
    pavucontrol     # audio GUI
    alacritty       # terminal emulator
    playerctl       # media player control
    adwaita-icon-theme  # icon package
    nwg-look               # GTK settings (action-2-1)
    libsForQt5.qtstyleplugin-kvantum  # only if you use Qt theming
    htop            # if not already present
    # bluez           # already present in l. 153
    # networkmanager  # already present in l. 32
    
    gvfs
    libnotify

    # apps
    ani-cli         # anime cli
    brave           # browser
    google-chrome   # browser
    mpv             # media player
    vesktop         # Discord (Wayland-native client)
    spotify         # Spotify
    spicetify-cli   # Spotify customization CLI
    teams-for-linux # microsoft teams (community version)
    libreoffice     # Office
    siyuan          # notetaking
    masterpdfeditor4 # pdfs 

    # dev
    vscodium        # editor
    claude-code     # agentic coding tool
    dotnet-sdk      # dotnet sdk
    python3         # python3
    devenv          # declarative development environments

    # gpu / diagnostics
    mesa-demos
    vulkan-tools
    libva-utils     # `vainfo` to verify VAAPI
    nvtopPackages.full
  ];

  fonts.packages = with pkgs; [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.noto
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
