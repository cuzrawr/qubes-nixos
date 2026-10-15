{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.qubes.desktop.enable =
    lib.mkEnableOption "the Qubes Xorg session with XFCE applications";

  config = lib.mkIf (config.services.qubes.enable && config.services.qubes.desktop.enable) {
    services.qubes.gui.enable = true;
    services.qubes.extraPackages = [
      pkgs.qubes.pdf-converter
      pkgs.qubes.img-converter
    ];
    services.xserver.desktopManager.xfce = {
      enable = true;
      noDesktop = true;
      enableXfwm = false;
      enableScreensaver = false;
      enableWaylandSession = false;
    };
    environment.xfce.excludePackages = [ pkgs.xfce4-notifyd ];
    programs.firefox.enable = lib.mkDefault true;
    environment.pathsToLink = [ "/etc/xdg/xfce4" ];
    # Apply the same action fragment as upstream's Fedora/Debian post-install.
    environment.etc."xdg/Thunar/uca.xml".source =
      pkgs.runCommand "qubes-thunar-actions.xml" { nativeBuildInputs = [ pkgs.libxml2 ]; }
        ''
          sed '$e cat ${pkgs.qubes.core-agent}/lib/qubes/uca_qubes.xml' \
            ${pkgs.thunar}/etc/xdg/Thunar/uca.xml > "$out"
          xmllint --noout "$out"
        '';
  };
}
