{
  config,
  lib,
  pkgs,
  ...
}:
let
  q = pkgs.qubes.core-agent;
  xenScripts = pkgs.buildEnv {
    name = "qubes-xen-scripts";
    paths = [
      pkgs.xen
      q
      pkgs.qubes.linux-utils
    ];
    pathsToLink = [ "/etc/xen/scripts" ];
  };
in
{
  config = lib.mkIf config.services.qubes.enable {
    networking.useDHCP = false;
    networking.hostName = lib.mkDefault "nixos";
    networking.firewall.enable = false;
    # The Qubes guest scripts consume QubesDB addresses and routes. Do not run
    # another automatic configurator on the Xen uplink.
    networking.useNetworkd = false;
    networking.resolvconf.enable = false;
    services.resolved.enable = true;
    # Upstream's service conditions enable NetworkManager only in qubes whose
    # network-manager service is enabled in dom0. Xen uplinks stay unmanaged.
    networking.networkmanager = {
      enable = lib.mkDefault true;
      dns = "systemd-resolved";
    };
    environment.etc = {
      "xen/scripts".source = "${xenScripts}/etc/xen/scripts";
      "tinyproxy/tinyproxy-updates.conf".source = "${q}/etc/tinyproxy/tinyproxy-updates.conf";
      "tinyproxy/updates-blacklist".source = "${q}/etc/tinyproxy/updates-blacklist";
      "systemd/network/80-qubes-vif.link".source = "${q}/lib/systemd/network/80-qubes-vif.link";
      "systemd/resolved.conf.d/30-qubes.conf".source =
        "${q}/lib/systemd/resolved.conf.d/30_resolved-no-mdns-or-llmnr.conf";
      "sysctl.d/81-qubes.conf.optional".source = "${q}/etc/sysctl.d/81-qubes.conf.optional";
      "sysctl.d/82-qubes-minimal-sys-net.conf.optional".source =
        "${q}/etc/sysctl.d/82-qubes-minimal-sys-net.conf.optional";
    }
    // lib.optionalAttrs config.networking.networkmanager.enable {
      "NetworkManager/conf.d/30-qubes.conf".source = "${q}/lib/NetworkManager/conf.d/30-qubes.conf";
      "NetworkManager/conf.d/31-randomize-mac.conf".source =
        "${q}/lib/NetworkManager/conf.d/31-randomize-mac.conf";
    };
    networking.networkmanager.dispatcherScripts = lib.mkIf config.networking.networkmanager.enable [
      { source = "${q}/etc/NetworkManager/dispatcher.d/qubes-nmhook"; }
      { source = "${q}/etc/NetworkManager/dispatcher.d/30-qubes-external-ip"; }
    ];
    users.users.tinyproxy = {
      isSystemUser = true;
      group = "tinyproxy";
    };
    users.groups.tinyproxy = { };
    systemd.tmpfiles.rules = [
      "d /run/xen 0755 root root -"
      "d /var/log/xen 0755 root root -"
      "d /var/lib/xen 0755 root root -"
      "d /run/tinyproxy-updates 0755 tinyproxy tinyproxy -"
    ];
    boot.kernel.sysctl."net.ipv6.conf.*.drop_unsolicited_na" = 1;
    # Upstream config-overrides/20_tcp_timestamps.conf.
    boot.kernel.sysctl."net.ipv4.tcp_timestamps" = lib.mkDefault 0;
    systemd.services = {
      qubes-antispoof.requiredBy = [ "network-pre.target" ];
      qubes-iptables.requiredBy = [ "network-pre.target" ];
      qubes-network.wantedBy = [ "multi-user.target" ];
      qubes-network-uplink.wantedBy = [ "multi-user.target" ];
      qubes-firewall.wantedBy = [ "multi-user.target" ];
      qubes-updates-proxy.wantedBy = [ "multi-user.target" ];
      NetworkManager = lib.mkIf config.networking.networkmanager.enable {
        path = [
          q
          pkgs.qubes.qubesdb
          pkgs.gnused
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.systemd
        ];
      };
      NetworkManager-dispatcher = lib.mkIf config.networking.networkmanager.enable {
        path = [
          q
          pkgs.qubes.qubesdb
          pkgs.systemd
        ];
      };
      wpa_supplicant =
        lib.mkIf (config.networking.wireless.enable && config.networking.wireless.dbusControlled)
          {
            after = [ "qubes-sysinit.service" ];
            unitConfig.ConditionPathExists = "/run/qubes-service/network-manager";
          };
    };
    systemd.sockets.qubes-updates-proxy-forwarder.wantedBy = [ "multi-user.target" ];
  };
}
