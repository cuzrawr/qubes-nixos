{
  config,
  lib,
  pkgs,
  ...
}:
let
  pipewireModules = pkgs.buildEnv {
    name = "qubes-pipewire-modules";
    paths = [
      config.services.pipewire.package
      pkgs.qubes.gui-agent.audio
    ];
    pathsToLink = [ "/lib/pipewire-0.3" ];
  };
in
{
  options.services.qubes.audio.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.services.qubes.desktop.enable;
    defaultText = lib.literalExpression "config.services.qubes.desktop.enable";
    description = "Enable Qubes audio through PipeWire.";
  };
  config = lib.mkIf (config.services.qubes.enable && config.services.qubes.audio.enable) {
    services.qubes.extraPackages = [ pkgs.qubes.gui-agent.audio ];
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      configPackages = [ pkgs.qubes.gui-agent.audio ];
    };
    systemd.user.services.pipewire.environment.PIPEWIRE_MODULE_DIR =
      "${pipewireModules}/lib/pipewire-0.3";
  };
}
