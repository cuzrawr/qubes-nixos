{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.qubes.splitGpg.enable = lib.mkEnableOption "upstream Qubes Split GPG 2";

  config = lib.mkIf (config.services.qubes.enable && config.services.qubes.splitGpg.enable) {
    services.qubes.extraPackages = [ pkgs.qubes.split-gpg2 ];
    environment.systemPackages = [ pkgs.gnupg ];
    environment.etc."gnupg/gpg.conf".source = "${pkgs.qubes.split-gpg2}/etc/gnupg/gpg.conf";
    # Upstream's condition checks the native split-gpg2-client Qubes service.
    systemd.user.services.split-gpg2-client.wantedBy = [ "default.target" ];
  };
}
