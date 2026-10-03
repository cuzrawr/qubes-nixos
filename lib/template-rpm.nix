{
  pkgs,
  image,
  name,
  version ? "4.3.0",
  release ? "1",
  templateConfig ? "virt-mode=pvh\n",
  appmenus ? [ "xterm.desktop" ],
}:
let
  sources = import ../pkgs/sources.nix {
    inherit (pkgs) lib fetchFromGitHub;
  };
  spec = "${sources.template-builder.src}/qubesbuilder/plugins/template/template.spec";
in
assert pkgs.lib.assertMsg (
  builtins.match "[a-zA-Z][a-zA-Z0-9_.-]*" name != null
) "Template names must be valid Qubes VM names.";
pkgs.runCommand "qubes-template-${name}-${version}-${release}"
  {
    nativeBuildInputs = [
      pkgs.rpm
      pkgs.gnutar
      pkgs.coreutils
      pkgs.util-linux
    ];
    TEMPLATE_NAME = name;
    TEMPLATE_VERSION = version;
    TEMPLATE_TIMESTAMP = release;
    templateConfigText = templateConfig;
    appmenusText = pkgs.lib.concatStringsSep "\n" appmenus + "\n";
    passAsFile = [
      "templateConfigText"
      "appmenusText"
    ];
  }
  ''
    mkdir -p "$out" build buildroots appmenus rpmtmp rpmdb "qubeized_images/$TEMPLATE_NAME"
    rpm --define "_dbpath $PWD/rpmdb" --initdb
    # Upstream sparsifies its input, so give it a writable copy, never a store link.
    cp --reflink=auto --sparse=always ${image}/root.img "qubeized_images/$TEMPLATE_NAME/root.img"
    chmod u+w "qubeized_images/$TEMPLATE_NAME/root.img"
    cp "$templateConfigTextPath" template.conf
    for list in whitelisted-appmenus vm-whitelisted-appmenus netvm-whitelisted-appmenus; do
      cp "$appmenusTextPath" "appmenus/$list.list"
    done
    rpmbuild -bb ${spec} \
      --define "_topdir $TMPDIR/rpmbuild" \
      --define "_sourcedir $PWD" \
      --define "_rpmdir $out" \
      --define "_builddir $PWD/build" \
      --define "_buildrootdir $PWD/buildroots" \
      --define "_tmppath $PWD/rpmtmp" \
      --define "_dbpath $PWD/rpmdb" \
      --define "_buildshell ${pkgs.bash}/bin/bash" \
      --define "_buildhost qubes-nixos" \
      --define "_binary_payload w19.zstdio" \
      --define "_build_id_links none"
    mv "$out"/noarch/*.rpm "$out/"
    rmdir "$out/noarch"
  ''
