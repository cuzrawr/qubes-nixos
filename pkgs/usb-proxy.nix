{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
  bash,
  tzdata,
  writeText,
  coreutils,
  gnugrep,
  gnused,
  nettools,
  systemd,
  kmod,
  usbutils,
  util-linux,
  qubesdb,
  qrexec,
  upstream,
}:
let
  paths = writeText "qubes-usb-paths.json" (
    builtins.toJSON (
      import ./guest-paths.nix { inherit bash tzdata; }
      // {
        "/usr/bin/udevadm" = "${systemd}/bin/udevadm";
      }
    )
  );
  runtime = lib.makeBinPath [
    coreutils
    gnugrep
    gnused
    nettools
    systemd
    kmod
    usbutils
    util-linux
    qubesdb
    qrexec
  ];
in
stdenvNoCC.mkDerivation {
  pname = "qubes-usb-proxy";
  inherit (upstream) version src;
  nativeBuildInputs = [
    python3
    makeWrapper
  ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    make install-vm DESTDIR="$out"
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr"
    ln -sfn "$out/lib/qubes/usb-detach-all" \
      "$out/etc/qubes/suspend-pre.d/usb-detach-all.sh"
    patchShebangs "$out"
    python3 ${./relocate-paths.py} "$out" ${paths}
    for helper in "$out/lib/qubes/"* "$out/etc/qubes-rpc/"*; do
      wrapProgram "$helper" --prefix PATH : "/run/wrappers/bin:${runtime}"
    done
    runHook postInstall
  '';
  meta = {
    description = "Upstream Qubes USB passthrough over qrexec";
    homepage = "https://github.com/QubesOS/qubes-app-linux-usb-proxy";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
