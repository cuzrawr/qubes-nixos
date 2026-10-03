{ pkgs, ... }:
{
  services.qubes.enable = true;
  system.stateVersion = "26.05";
  networking.hostName = "nixos-boot-test";
  networking.useDHCP = false;
  users.users.root.hashedPassword = "";
  services.getty.autologinUser = "root";
  documentation.enable = false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # This diagnostic is present only in the boot experiment, never a release.
  systemd.services.qubes-boot-test = {
    description = "Validate NixOS activation under the Qubes kernel";
    wantedBy = [ "multi-user.target" ];
    after = [
      "local-fs.target"
      "systemd-modules-load.service"
    ];
    path = [
      pkgs.coreutils
      pkgs.kmod
    ];
    script = ''
      set -eu
      test "$(cat /sys/hypervisor/type)" = xen
      test -L /run/current-system
      test -L /run/booted-system
      test -f /etc/os-release
      test -d "/lib/modules/$(uname -r)/kernel"
      for module in xen_evtchn xen_gntdev xen_gntalloc; do
        modprobe "$module"
      done
      test -c /dev/xen/evtchn
      test -c /dev/xen/gntdev
      test -c /dev/xen/gntalloc
      echo "QUBES_NIXOS_BOOT_TEST_PASS kernel=$(uname -r) system=$(readlink /run/current-system)"
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };
}
