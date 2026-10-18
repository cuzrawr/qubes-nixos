{
  config,
  # deadnix: skip
  pkgs,
  ...
}:
{
  services.qubes = {
    gui.enable = true;
    passwordlessRoot.enable = false;
    usb.enable = false;
  };
  networking.networkmanager.enable = false;
  services.pipewire.enable = config.services.qubes.audio.enable;

  # example: [ pkgs.htop ]. enable optional Qubes roles above as needed.
  environment.systemPackages = [ ];
}
