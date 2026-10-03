{
  pkgs,
  lib,
  config,
  contents ? [ ],
}:
lib.overrideDerivation
  (import (pkgs.path + "/nixos/lib/make-disk-image.nix") {
    inherit
      pkgs
      lib
      config
      contents
      ;
    name = "qubes-${config.system.nixos.label}";
    baseName = "root";
    format = "raw";
    # Qubes' stock initramfs recognizes a GPT root at partition 3.
    partitionTableType = "hybrid";
    bootSize = "32M";
    diskSize = "auto";
    # Leave room for evaluation and a replacement generation before collection.
    additionalSpace = "4G";
    copyChannel = false;
    memSize = 768;
  })
  (_: {
    # Image finalization must also work inside a qube, where KVM is unavailable.
    requiredSystemFeatures = [ ];
    enableParallelBuilding = false;
  })
