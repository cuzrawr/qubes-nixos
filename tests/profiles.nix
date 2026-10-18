{
  pkgs,
  full,
  minimal,
}:
let
  inherit (pkgs) lib;
  hasAudio = system: system.config.systemd.user.sockets ? pipewire;
  withAudio = system: system.extendModules { modules = [ { services.qubes.audio.enable = true; } ]; };
in
assert lib.assertMsg (lib.all hasAudio full) "XFCE profiles must retain PipeWire socket activation";
assert lib.assertMsg (lib.all (
  system: !hasAudio system
) minimal) "minimal profiles must not activate PipeWire by default";
assert lib.assertMsg (lib.all (
  system: hasAudio (withAudio system)
) minimal) "minimal profiles must support the optional audio role";
pkgs.runCommand "qubes-profile-tests" { } ''
  touch "$out"
''
