{ pkgs, ... }:
{
  services.qubes = {
    enable = true;
    desktop.enable = true;
    splitGpg.enable = true;
    updateVM.enable = true;
  };

  # Edit this list, then rebuild in the TemplateVM.
  environment.systemPackages = with pkgs; [
    atril
    claws-mail
    galculator
    geany
    keepassxc
    xarchiver
  ];
  # Keep manual pages; omit separate developer documentation from the image.
  documentation.doc.enable = false;
  documentation.info.enable = false;
  # Match NixOS's installer profile: retain one MBROLA voice per language.
  nixpkgs.overlays = [
    (_: prev: {
      mbrola-voices = prev.mbrola-voices.override { languages = [ "*1" ]; };
    })
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    min-free = 1024 * 1024 * 1024;
    max-free = 3 * 1024 * 1024 * 1024;
  };
  # Keep this at the version used when the template was first installed.
  system.stateVersion = "26.05";
}
