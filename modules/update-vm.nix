{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.qubes.updateVM;
  helper = "/usr/lib/qubes/qubes-download-dom0-updates.sh";
in
{
  options.services.qubes.updateVM.enable = lib.mkEnableOption "the native Qubes UpdateVM role";

  config = lib.mkIf config.services.qubes.enable {
    services.qubes.extraPackages = lib.optionals cfg.enable [ pkgs.qubes.update-vm ];
    # Dom0 invokes this exact guest path. Keep this one public entry point;
    # the helper and all its dependencies remain in the immutable store.
    systemd.tmpfiles.rules =
      if cfg.enable then
        [
          "L+ ${helper} - - - - ${pkgs.qubes.update-vm}/lib/qubes/qubes-download-dom0-updates.sh"
          "d /var/lib/qubes/dom0-updates 2775 root qubes -"
        ]
      else
        [
          "r ${helper} - - - -"
        ];
  };
}
