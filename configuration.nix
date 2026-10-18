{ pkgs, ... }:
{
  services.qubes = {
    enable = true;
    desktop.enable = true;
    splitGpg.enable = true;
    updateVM.enable = true;
  };

  # edit this list, then rebuild in the TemplateVM.
  environment.systemPackages = with pkgs; [
    atril
    claws-mail
    galculator
    geany
    keepassxc
    xarchiver
  ];
}
