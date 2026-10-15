{ pkgs, ... }:
{
  services.qubes = {
    gui.enable = true;
    passwordlessRoot.enable = false;
    usb.enable = false;
  };
  networking.networkmanager.enable = false;

  # Example: [ pkgs.htop ]. Enable optional Qubes roles above as needed.
  environment.systemPackages = [ ];
}
