{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.services.qubes.enable {
    users.groups.qubes = { };
    users.users.user = {
      isNormalUser = true;
      uid = 1000;
      group = "users";
      extraGroups = [
        "qubes"
        "wheel"
      ];
      initialHashedPassword = "";
    };
    users.users.root.initialHashedPassword = "";

    # As in the standard Qubes templates, isolation is between qubes. The
    # desktop user can administer its own qube without a separate password.
    security.sudo.wheelNeedsPassword = false;
    # Preserve upstream Qubes' umask and Qt behavior for privileged commands.
    security.sudo.extraConfig = ''
      Defaults umask = 0022
      Defaults umask_override
      Defaults env_keep += "QT_X11_NO_MITSHM"
    '';
    security.pam.services = {
      qrexec = {
        rootOK = true;
        setLoginUid = true;
      };
      su.rules.auth.qubes = {
        order = config.security.pam.services.su.rules.auth.unix.order - 10;
        control = "sufficient";
        modulePath = "${pkgs.pam}/lib/security/pam_succeed_if.so";
        settings = {
          use_uid = true;
          quiet = true;
        };
        args = [
          "user"
          "ingroup"
          "qubes"
        ];
      };
    };
    security.pam.loginLimits = [
      {
        domain = "@qubes";
        type = "-";
        item = "nproc";
        value = "51200";
      }
    ];
    security.wrappers.qfile-unpacker = {
      source = "${pkgs.qubes.core-agent}/bin/qfile-unpacker";
      owner = "root";
      group = "root";
      setuid = true;
    };
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("qubes")) return polkit.Result.YES;
      });
    '';
  };
}
