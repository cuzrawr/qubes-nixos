{ pkgs, ... }:
{
  services.qubes.enable = true;
  system.stateVersion = "26.05";
  documentation.enable = false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Console diagnostics belong only to the test image.
  services.getty.autologinUser = "root";
  systemd.services.qubes-core-test = {
    description = "Validate Qubes guest service startup";
    wantedBy = [ "multi-user.target" ];
    after = [
      "qubes-qrexec-agent.service"
      "qubes-misc-post.service"
      "qubes-network-uplink.service"
    ];
    path = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.systemd
      pkgs.qubes.qubesdb
    ];
    script = ''
      set -eu
      for unit in qubes-db qubes-qrexec-agent qubes-sysinit qubes-mount-dirs qubes-bind-dirs; do
        systemctl is-active --quiet "$unit"
      done
      test "$(qubesdb-read /name)" = "$(cat /proc/sys/kernel/hostname)"
      test "$(id -u user)" = 1000
      mountpoint -q /rw
      mountpoint -q /home
      mountpoint -q /usr/local
      test -d /home/user
      if [ -n "$(qubesdb-read --default= /qubes-ip)" ]; then
        systemctl is-active --quiet qubes-network-uplink
      fi
      echo "QUBES_NIXOS_CORE_TEST_PASS name=$(qubesdb-read /name) system=$(readlink /run/current-system)"
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };
}
