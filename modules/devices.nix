{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.qubes.usb.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Install Qubes' native USB attachment and export RPC services.";
  };
  config = lib.mkIf (config.services.qubes.enable && config.services.qubes.usb.enable) {
    services.qubes.extraPackages = [
      pkgs.qubes.usb-proxy
      pkgs.qubes.input-proxy
    ];
    environment.systemPackages = [ pkgs.usbutils ];
    environment.etc."modules-load.d/qubes-uinput.conf".source =
      "${pkgs.qubes.input-proxy}/lib/modules-load.d/qubes-uinput.conf";
  };
}
