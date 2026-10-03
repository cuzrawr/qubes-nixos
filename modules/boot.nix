{ config, lib, ... }:
{
  options.services.qubes.enable = lib.mkEnableOption "Qubes OS guest integration";

  config = lib.mkIf config.services.qubes.enable {
    # Qubes supplies the kernel, initramfs and matching /lib/modules over xvdd.
    # Disabling the NixOS initrd selects its supported stage-2 activation entry.
    boot.kernel.enable = lib.mkDefault false;
    boot.initrd.enable = lib.mkDefault false;
    boot.loader.grub.enable = lib.mkDefault false;
    boot.loader.initScript.enable = true;

    fileSystems."/" = {
      device = lib.mkDefault "/dev/mapper/dmroot";
      fsType = lib.mkDefault "ext4";
      options = [ "noatime" ];
    };

    boot.kernelModules = [
      "xen_evtchn"
      "xen_gntdev"
      "xen_gntalloc"
    ];
    # nixpkgs emits this configuration only when it also builds the kernel.
    # Stock NixOS kmod already searches the externally mounted /lib/modules.
    environment.etc."modules-load.d/qubes.conf".text =
      lib.concatStringsSep "\n" config.boot.kernelModules + "\n";
    systemd.services.systemd-modules-load.wantedBy = [ "sysinit.target" ];
    # NixOS normally tests its own kernel tree here. Use the modules supplied
    # by Qubes so static device nodes (loop-control, rfkill) work normally.
    systemd.services.kmod-static-nodes.unitConfig.ConditionFileNotEmpty = lib.mkForce [
      ""
      "/lib/modules/%v/modules.devname"
    ];
    systemd.tmpfiles.rules = [ "d /lib/modules 0755 root root -" ];

    assertions = [
      {
        assertion = !config.boot.initrd.enable && !config.boot.kernel.enable;
        message = "The Qubes external-kernel profile uses dom0's kernel and initrd. Keep boot.kernel.enable and boot.initrd.enable false.";
      }
      {
        assertion = config.boot.loader.initScript.enable && !config.boot.loader.grub.enable;
        message = "The Qubes external-kernel profile requires the NixOS /sbin/init loader, without GRUB.";
      }
      {
        assertion = config.fileSystems."/".device == "/dev/mapper/dmroot";
        message = "Qubes' initramfs exposes the root volume at /dev/mapper/dmroot.";
      }
    ];
  };
}
