{ lib, ... }:
{
  services.qubes.enable = lib.mkDefault true;

  # keep manual pages; omit separate developer documentation from the image.
  documentation.doc.enable = lib.mkDefault false;
  documentation.info.enable = lib.mkDefault false;
  # match NixOS's installer profile: retain one MBROLA voice per language.
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
    auto-optimise-store = lib.mkDefault true;
    min-free = lib.mkDefault (1024 * 1024 * 1024);
    max-free = lib.mkDefault (3 * 1024 * 1024 * 1024);
  };
  # keep this at the version used when the template was first installed.
  system.stateVersion = lib.mkDefault "26.05";
}
