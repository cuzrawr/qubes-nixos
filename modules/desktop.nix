{
  config,
  lib,
  pkgs,
  ...
}:
let
  q = pkgs.qubes;
  session = pkgs.writeShellScript "qubes-xfce-session" ''
    # The same hooks selected by upstream's Fedora XFCE package.
    for hook in \
      ${q.gui-agent}/etc/X11/xinit/xinitrc.d/20qt-x11-no-mitshm.sh \
      ${q.gui-agent}/etc/X11/xinit/xinitrc.d/20qt-gnome-desktop-session-id.sh \
      ${q.gui-agent}/etc/X11/xinit/xinitrc.d/50guivm-windows-prefix.sh \
      ${q.gui-agent}/etc/X11/xinit/xinitrc.d/60xfce-desktop.sh; do
      . "$hook"
    done
    exec ${q.gui-agent}/bin/qubes-session
  '';
  pipewireModules = pkgs.buildEnv {
    name = "qubes-pipewire-modules";
    paths = [
      config.services.pipewire.package
      q.gui-agent
    ];
    pathsToLink = [ "/lib/pipewire-0.3" ];
  };
in
{
  options.services.qubes.desktop.enable =
    lib.mkEnableOption "the Qubes Xorg session with XFCE applications";

  config = lib.mkIf (config.services.qubes.enable && config.services.qubes.desktop.enable) {
    services.qubes.extraPackages = [
      q.gui-agent
      q.pdf-converter
      q.img-converter
      q.notification-proxy
    ];
    services.xserver = {
      enable = true;
      displayManager.lightdm.enable = false;
      desktopManager.xfce = {
        enable = true;
        noDesktop = true;
        enableXfwm = false;
        enableScreensaver = false;
        enableWaylandSession = false;
      };
    };
    # Dom0 supplies the window manager. The guest has no login greeter or panel.
    services.displayManager.enable = false;
    environment.xfce.excludePackages = [ pkgs.xfce4-notifyd ];
    systemd.user.services.qubes-notification-agent.wantedBy = [ "default.target" ];
    programs.firefox.enable = lib.mkDefault true;
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
    environment.pathsToLink = [ "/etc/xdg/xfce4" ];
    environment.extraInit = ''
      . ${q.gui-agent}/etc/profile.d/qubes-gui.sh
      . ${q.gui-agent}/etc/X11/xinit/xinitrc.d/20qt-x11-no-mitshm.sh
    '';

    environment.etc = {
      # Apply the same action fragment as upstream's Fedora/Debian post-install.
      "xdg/Thunar/uca.xml".source =
        pkgs.runCommand "qubes-thunar-actions.xml"
          {
            nativeBuildInputs = [ pkgs.libxml2 ];
          }
          ''
            sed '$e cat ${q.core-agent}/lib/qubes/uca_qubes.xml' \
              ${pkgs.thunar}/etc/xdg/Thunar/uca.xml > "$out"
            xmllint --noout "$out"
          '';
      "X11/xorg-qubes.conf.template".source = "${q.gui-agent}/etc/X11/xorg-qubes.conf.template";
      "X11/xorg.conf.d/10-qubes-modules.conf".text = ''
        Section "Files"
          ModulePath "${q.gui-agent}/lib/xorg/modules"
          ModulePath "${pkgs.xorg-server}/lib/xorg/modules"
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

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      configPackages = [ q.gui-agent ];
    };
    systemd.user.services.pipewire.environment.PIPEWIRE_MODULE_DIR =
      "${pipewireModules}/lib/pipewire-0.3";
  };
}
