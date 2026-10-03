{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.qubes;
  q = pkgs.qubes;
  corePackages = [
    q.qubesdb
    q.qrexec
    q.linux-utils
    q.core-agent
  ];
  packages = corePackages ++ cfg.extraPackages;
  etcTree = pkgs.buildEnv {
    name = "qubes-guest-etc";
    paths = packages;
    pathsToLink = [
      "/etc/qubes"
      "/etc/qubes-rpc"
    ];
  };
  runtime =
    corePackages
    ++ (with pkgs; [
      bash
      coreutils
      diffutils
      findutils
      gnugrep
      gnused
      gawk
      getent
      glibc.bin
      util-linux
      e2fsprogs
      parted
      lvm2
      kmod
      systemd
      procps
      nettools
      iproute2
      nftables
      iptables
      xdg-utils
      which
      python3
      dbus
      gnutar
      socat
      graphicsmagick
      librsvg
      zenity
      dconf
      conntrack-tools
      tinyproxy
      xen
    ]);
  # The upstream units retain their commands, ordering and runtime conditions.
  # NixOS enables them explicitly instead of running a distribution preset.
  services = [
    "qubes-db"
    "qubes-qrexec-agent"
    "qubes-meminfo-writer"
    "qubes-sysinit"
    "qubes-early-vm-config"
    "qubes-misc-post"
    "qubes-mount-dirs"
    "qubes-bind-dirs"
    "qubes-rootfs-resize"
    "qubes-antispoof"
    "qubes-iptables"
    "qubes-network"
    "qubes-network-uplink"
    "qubes-network-uplink@"
    "qubes-firewall"
    "qubes-sync-time"
    "qubes-updates-proxy-forwarder@"
    "dev-xvdc1-swap"
    "systemd-random-seed"
    "xendriverdomain"
    "qubes-updates-proxy"
  ];
in
{
  options.services.qubes.extraPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Additional Qubes guest packages, including their RPC and service files.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = runtime ++ cfg.extraPackages;
    environment.pathsToLink = [
      "/lib/qubes"
      "/lib/qubes-bind-dirs.d"
      "/share/qubes"
      "/sbin"
    ];
    environment.etc = {
      "qubes".source = "${etcTree}/etc/qubes";
      "qubes-rpc".source = "${etcTree}/etc/qubes-rpc";
      # Use upstream's complete list, including privcmd required by libvchan.
      "modules-load.d/qubes-core.conf".source = "${q.core-agent}/lib/modules-load.d/qubes-core.conf";
      "qubes-suspend-module-blacklist".source = "${q.core-agent}/etc/qubes-suspend-module-blacklist";
      "sysctl.d/20-qubes-core.conf".source = "${q.core-agent}/lib/sysctl.d/20-qubes-core.conf";
      "systemd/user-environment-generators/30-qubes.sh".source =
        "${q.core-agent}/lib/systemd/user-environment-generators/30-qubes.sh";
    };

    systemd.packages = packages;
    systemd.tmpfiles.packages = [
      q.qrexec
      q.linux-utils
      q.core-agent
    ];
    services.udev.packages = packages;
    systemd.services =
      lib.recursiveUpdate
        (lib.genAttrs services (_: {
          path = runtime;
        }))
        {
          qubes-db.wantedBy = [ "sysinit.target" ];
          qubes-sysinit.wantedBy = [ "sysinit.target" ];
          qubes-early-vm-config.wantedBy = [ "sysinit.target" ];
          dev-xvdc1-swap.wantedBy = [ "sysinit.target" ];
          qubes-qrexec-agent.wantedBy = [ "multi-user.target" ];
          # User services restart during activation and still need qrexec.
          # Restart the transport afterward instead of stopping it beforehand.
          qubes-qrexec-agent.stopIfChanged = false;
          qubes-meminfo-writer.wantedBy = [ "multi-user.target" ];
          qubes-misc-post.wantedBy = [ "multi-user.target" ];
          xendriverdomain.wantedBy = [ "multi-user.target" ];
          # The same post-transaction hook used by upstream's DNF integration.
          # A Nix generation change must also refresh menus and guest features.
          qubes-post-install = {
            wantedBy = [ "multi-user.target" ];
            after = [ "qubes-qrexec-agent.service" ];
            requires = [ "qubes-qrexec-agent.service" ];
            unitConfig.ConditionPathExists = "/run/qubes/persistent-full";
            restartTriggers = [ config.system.path ];
            path = runtime;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${q.core-agent}/etc/qubes-rpc/qubes.PostInstall";
            };
          };
        };

    # Upstream seed handling imports fresh entropy supplied by dom0 before use.
    systemd.timers.qubes-sync-time.wantedBy = [ "timers.target" ];
    services.timesyncd.enable = lib.mkDefault false;
    services.dbus.enable = true;
  };
}
