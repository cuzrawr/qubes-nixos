{ bash }:
{
  # NixOS builds this shared profile from declared guest runtime dependencies.
  "/usr/lib/qubes/qfile-unpacker" = "/run/wrappers/bin/qfile-unpacker";
  "/usr/lib/qubes-bind-dirs.d" = "/run/current-system/sw/lib/qubes-bind-dirs.d";
  "/usr/bin/sudo" = "/run/wrappers/bin/sudo";
  "/bin/su" = "/run/wrappers/bin/su";
  "/usr/share/qubes" = "/run/current-system/sw/share/qubes";
  "/usr/share/applications" = "/run/current-system/sw/share/applications";
  "/usr/share/icons" = "/run/current-system/sw/share/icons";
  "/usr/share/pixmaps" = "/run/current-system/sw/share/pixmaps";
  # timedated recognizes the timezone through NixOS's native catalog path.
  "../usr/share/zoneinfo" = "/etc/zoneinfo";
  "/usr/share/zoneinfo" = "/etc/zoneinfo";
  "/bin/bash" = "${bash}/bin/bash";
  "/bin/sh" = "${bash}/bin/sh";
}
