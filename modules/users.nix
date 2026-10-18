{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.services.qubes.passwordlessRoot.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Allow the qube's desktop user to administer it without a password.";
  };

  config = lib.mkIf config.services.qubes.enable {
    users.groups.qubes = { };
    users.users.user = {
      isNormalUser = true;
      uid = 1000;
      group = "users";
      extraGroups = [ "qubes" ] ++ lib.optional config.services.qubes.passwordlessRoot.enable "wheel";
      initialHashedPassword = if config.services.qubes.passwordlessRoot.enable then "" else "!";
    };
    users.users.root =
      if config.services.qubes.passwordlessRoot.enable then
        {
          initialHashedPassword = lib.mkDefault "";
        }
      else
        {
          hashedPassword = lib.mkDefault "!";
        };

    # as in the standard Qubes templates, isolation is between qubes. the
    # desktop user can administer its own qube without a separate password.
    security.sudo.wheelNeedsPassword = lib.mkIf config.services.qubes.passwordlessRoot.enable false;
    # preserve upstream Qubes' umask and Qt behavior for privileged commands.
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
      su.rules.auth.qubes = lib.mkIf config.services.qubes.passwordlessRoot.enable {
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
    security.polkit.extraConfig = lib.mkIf config.services.qubes.passwordlessRoot.enable ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("qubes")) return polkit.Result.YES;
      });
    '';
  };
}
