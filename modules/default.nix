{ config, lib, ... }:
{
  imports = [
    ./boot.nix
    ./core.nix
    ./persistence.nix
    ./networking.nix
    ./users.nix
    ./desktop.nix
    ./devices.nix
    ./updates.nix
    ./update-vm.nix
    ./split-gpg.nix
  ];
  config = lib.mkIf config.services.qubes.enable {
    nixpkgs.overlays = [ (import ../pkgs/overlay.nix) ];
  };
}
