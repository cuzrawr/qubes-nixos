{
  config,
  lib,
  pkgs,
  ...
}:
let
  q = pkgs.qubes;
  hooks = [
    "${q.gui-agent}/etc/X11/xinit/xinitrc.d/20qt-x11-no-mitshm.sh"
    "${q.gui-agent}/etc/X11/xinit/xinitrc.d/20qt-gnome-desktop-session-id.sh"
    "${q.gui-agent}/etc/X11/xinit/xinitrc.d/50guivm-windows-prefix.sh"
  ]
  ++ lib.optional config.services.qubes.desktop.enable "${q.gui-agent}/etc/X11/xinit/xinitrc.d/60xfce-desktop.sh";
  session = pkgs.writeShellScript "qubes-x-session" ''
    for hook in ${lib.escapeShellArgs hooks}; do
      . "$hook"
    done
    exec ${q.gui-agent}/bin/qubes-session
  '';
in
{
  options.services.qubes.gui.enable = lib.mkEnableOption "the native Qubes Xorg session";

  config = lib.mkIf (config.services.qubes.enable && config.services.qubes.gui.enable) {
    services.qubes.extraPackages = [
      q.gui-agent
      q.notification-proxy
    ];
    services.xserver = {
      enable = true;
      displayManager.lightdm.enable = false;
    };
    # dom0 supplies the window manager. the guest has no login greeter or panel.
    services.displayManager.enable = false;
    # Qubes supplies the main Xorg config. export NixOS's font directory to
    # its Files section instead of relying on Xorg's compiled-in FHS paths.
    fonts.fontDir.enable = lib.mkDefault true;
    # materialize core fonts so Xorg can load them without following symlinks.
    fonts.fontDir.decompressFonts = lib.mkDefault true;
    services.xserver.serverFlagsSection = lib.mkIf config.fonts.fontDir.enable (
      lib.mkDefault ''Option "UseDefaultFontPath" "false"''
    );
    systemd.user.services.qubes-notification-agent.wantedBy = [ "default.target" ];
    environment.systemPackages = with pkgs; [
      xorg-server
      xinit
      xsetroot
      xprop
      xrandr
      setxkbmap
      xkbcomp
      xdpyinfo
      xauth
      xterm
      zenity
      xdg-user-dirs
      libnotify
    ];
    environment.extraInit = ''
      . ${q.gui-agent}/etc/profile.d/qubes-gui.sh
      . ${q.gui-agent}/etc/X11/xinit/xinitrc.d/20qt-x11-no-mitshm.sh
    '';

    environment.etc = {
      "X11/xorg-qubes.conf.template".source = "${q.gui-agent}/etc/X11/xorg-qubes.conf.template";
      "X11/xorg.conf.d/10-qubes-modules.conf".text = ''
        Section "Files"
          ${lib.optionalString (
            config.services.xserver.fontPath != null
          ) ''FontPath "${config.services.xserver.fontPath}"''}
          ${config.services.xserver.filesSection}
          ModulePath "${q.gui-agent}/lib/xorg/modules"
          ModulePath "${pkgs.xorg-server}/lib/xorg/modules"
        EndSection
        Section "ServerFlags"
          ${config.services.xserver.serverFlagsSection}
        EndSection
      '';
      "X11/xinit/xinitrc".source = pkgs.writeShellScript "qubes-xinitrc" ''
        exec ${config.services.displayManager.sessionData.wrapper} ${session}
      '';
    };

    security.pam.services.qubes-gui-agent = {
      rootOK = true;
      startSession = true;
    };
    security.pam.loginLimits = [
      {
        domain = "@qubes";
        type = "-";
        item = "memlock";
        value = "131072";
      }
      {
        domain = "@qubes";
        type = "-";
        item = "nice";
        value = "-20";
      }
      {
        domain = "@qubes";
        type = "-";
        item = "rtprio";
        value = "unlimited";
      }
    ];
    boot.kernel.sysctl."vm.compact_unevictable_allowed" = 0;
    systemd.services.qubes-gui-agent = {
      wantedBy = [ "multi-user.target" ];
      path = [
        q.qubesdb
        pkgs.coreutils
        pkgs.gnused
      ];
      environment.ENV_PATH = "/run/wrappers/bin:/run/current-system/sw/bin:/run/current-system/sw/sbin:/usr/local/bin";
    };

  };
}
