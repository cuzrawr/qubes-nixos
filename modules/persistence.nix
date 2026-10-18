{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.services.qubes.enable {
    # upstream mount-dirs initializes the private device before mounting it.
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
      # the early upstream unit waits for all udev jobs, including network
      # jobs that need local-fs.target. run the same helper after that barrier.
      qubes-rootfs-resize.enable = false;
      qubes-nixos-rootfs-resize = {
        description = "Adjust root filesystem size";
        wantedBy = [ "multi-user.target" ];
        after = [
          "qubes-sysinit.service"
          "dev-xvda.device"
          "network.target"
        ];
        before = [ "qubes-qrexec-agent.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.qubes.core-agent}/lib/qubes/init/resize-rootfs-if-needed.sh";
        };
      };
    };
    # qubes-bind-dirs requires the upstream home.mount and usr-local.mount.
    # their runtime conditions also support Qubes' custom-persist feature.
    systemd.tmpfiles.rules = [
      "d /var/lib/qubes 0755 root root -"
      "d /etc/qubes-bind-dirs.d 0755 root root -"
    ];
  };
}
