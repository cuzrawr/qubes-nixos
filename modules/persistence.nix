{ config, lib, ... }:
{
  config = lib.mkIf config.services.qubes.enable {
    # Upstream mount-dirs initializes the private device before mounting it.
    fileSystems."/rw" = {
      device = "/dev/xvdb";
      fsType = "auto";
      options = [
        "noauto"
        "discard"
        "nosuid"
        "nodev"
      ];
    };
    systemd.services = {
      qubes-mount-dirs = {
        wantedBy = [ "multi-user.target" ];
        preStart = ''
          install -d -m0755 /rw /home /usr/local /etc/skel /var/lib/qubes
        '';
      };
      qubes-bind-dirs.wantedBy = [ "multi-user.target" ];
      qubes-rootfs-resize.wantedBy = [ "multi-user.target" ];
    };
    # qubes-bind-dirs requires the upstream home.mount and usr-local.mount.
    # Their runtime conditions also support Qubes' custom-persist feature.
    systemd.tmpfiles.rules = [
      "d /var/lib/qubes 0755 root root -"
      "d /etc/qubes-bind-dirs.d 0755 root root -"
    ];
  };
}
