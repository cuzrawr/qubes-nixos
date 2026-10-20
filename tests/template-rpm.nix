{ pkgs }:
let
  accepts =
    name:
    (builtins.tryEval
      (import ../lib/template-rpm.nix {
        inherit pkgs name;
        image = "/unused-image";
      }).drvPath
    ).success;
  validNames = [
    "nixos-26.05-xfce"
    "A_0.example"
    "a123456789012345678901234567890"
  ];
  invalidNames = [
    ""
    "1nixos"
    "nixos/name"
    "nixos name"
    "a1234567890123456789012345678901"
    "Domain-0"
    "none"
    "default"
    "nixos-dm"
  ];
in
assert pkgs.lib.assertMsg (
  pkgs.lib.all accepts validNames && pkgs.lib.all (name: !accepts name) invalidNames
) "Template RPM name validation must match Qubes VM name restrictions";
pkgs.runCommand "qubes-template-rpm-tests" { } ''
  touch "$out"
''
