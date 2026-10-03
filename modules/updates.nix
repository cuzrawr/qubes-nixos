{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.qubes.updates;
  runtime = [
    config.nix.package
    pkgs.nixos-rebuild
    pkgs.qubes.qrexec
  ];
  proxySetup = ''
    if [ -f /run/qubes-service/updates-proxy-setup ] &&
       [ ! -f /run/qubes-service/qubes-updates-proxy ]; then
      export http_proxy=http://127.0.0.1:8082 https_proxy=http://127.0.0.1:8082
      export no_proxy=localhost,127.0.0.1,::1
    fi
  '';
  gui = pkgs.writeShellScript "qubes-nixos-update-gui" ''
    if [ ! -f /run/qubes/persistent-full ]; then
      exec ${pkgs.zenity}/bin/zenity --info --text="Install system updates in this qube's TemplateVM, then restart this qube."
    fi
    exec ${pkgs.xterm}/bin/xterm -T "NixOS template update" -e ${pkgs.bash}/bin/bash -c '
      /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl start --no-block qubes-nixos-update || exit
      echo "Updating in the background. You may close this window."
      exec /run/wrappers/bin/sudo ${pkgs.systemd}/bin/journalctl --follow --no-pager --since="5 seconds ago" --unit=qubes-nixos-update
    '
  '';
  rpc = pkgs.runCommand "qubes-nixos-update-rpc" { } ''
    mkdir -p "$out/etc/qubes-rpc"
    ln -s ${gui} "$out/etc/qubes-rpc/qubes.InstallUpdatesGUI"
  '';
  check = pkgs.writeShellScript "qubes-nixos-update-check" (
    ''
      set -euo pipefail
    ''
    + proxySetup
    + ''
      scratch=$(mktemp -d)
      trap 'rm -rf "$scratch"' EXIT
      nix flake update --flake ${lib.escapeShellArg cfg.directory} --output-lock-file "$scratch/flake.lock" ${lib.escapeShellArgs cfg.inputs}
      candidate=$(nix eval --raw --no-write-lock-file --reference-lock-file "$scratch/flake.lock" ${lib.escapeShellArg "path:${cfg.directory}#nixosConfigurations.${cfg.configuration}.config.system.build.toplevel.outPath"})
      if [ "$candidate" = "$(readlink -f /run/current-system)" ]; then count=0; else count=1; fi
      printf '%s\n' "$count" | qrexec-client-vm dom0 qubes.NotifyUpdates
    ''
  );
in
{
  options.services.qubes.updates = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Qubes update RPC, proxy and notifications for the NixOS flake.";
    };
    directory = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "Writable directory containing the configuration flake.";
    };
    configuration = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "Name in the flake's nixosConfigurations.";
    };
    inputs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nixpkgs" ];
      description = "Flake inputs refreshed when checking or installing updates.";
    };
  };

  config = lib.mkIf (config.services.qubes.enable && cfg.enable) {
    environment.extraInit = proxySetup;
    # Upstream explicitly supports distribution-specific InstallUpdatesGUI.
    services.qubes.extraPackages = lib.optionals config.services.qubes.desktop.enable [
      (lib.hiPrio rpc)
    ];

    # Login shells and the daemon need the same role-dependent environment.
    systemd.services.qubes-nix-proxy = {
      after = [ "qubes-sysinit.service" ];
      requires = [ "qubes-sysinit.service" ];
      before = [ "nix-daemon.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = proxySetup + ''
        install -d /run/qubes
        printf 'http_proxy=%s\nhttps_proxy=%s\nno_proxy=%s\n' \
          "''${http_proxy-}" "''${https_proxy-}" "''${no_proxy-}" > /run/qubes/nix-proxy.env
      '';
    };
    systemd.services.nix-daemon = {
      after = [
        "qubes-nix-proxy.service"
        "qubes-updates-proxy-forwarder.socket"
      ];
      requires = [ "qubes-nix-proxy.service" ];
      serviceConfig.EnvironmentFile = "/run/qubes/nix-proxy.env";
    };

    # systemd serializes starts and survives the update window closing.
    # A configuration switch must not restart its own update service.
    systemd.services.qubes-nixos-update = {
      description = "Update the NixOS template";
      after = [
        "qubes-sysinit.service"
        "qubes-qrexec-agent.service"
      ];
      unitConfig.ConditionPathExists = "/run/qubes/persistent-full";
      restartIfChanged = false;
      stopIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "infinity";
      };
      path = runtime;
      script = proxySetup + ''
        cp --backup=numbered ${lib.escapeShellArg "${cfg.directory}/flake.lock"} /var/lib/qubes/flake.lock.previous
        nix flake update --flake ${lib.escapeShellArg cfg.directory} ${lib.escapeShellArgs cfg.inputs}
        nixos-rebuild switch --flake ${lib.escapeShellArg "${cfg.directory}#${cfg.configuration}"} --no-update-lock-file
        printf '0\n' | qrexec-client-vm dom0 qubes.NotifyUpdates
        echo "Update applied. Shut down the template, then restart dependent qubes."
      '';
    };
    systemd.services.qubes-update-check = {
      unitConfig.ConditionPathExists = [ "/run/qubes/persistent-full" ];
      path = runtime;
      # Reset upstream's distribution-specific command and failure suppression.
      serviceConfig.ExecStart = [
        ""
        "${check}"
      ];
    };
    systemd.timers.qubes-update-check.wantedBy = [ "timers.target" ];
  };
}
