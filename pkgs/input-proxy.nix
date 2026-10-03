{
  lib,
  stdenv,
  python3,
  makeWrapper,
  bash,
  tzdata,
  writeText,
  coreutils,
  gnugrep,
  systemd,
  qrexec,
  upstream,
}:
let
  python = python3.withPackages (ps: [ ps.pyinotify ]);
  paths = writeText "qubes-input-paths.json" (
    builtins.toJSON (
      import ./guest-paths.nix { inherit bash tzdata; }
      // {
        "/usr/bin/qrexec-client-vm" = "${qrexec}/bin/qrexec-client-vm";
        "/bin/systemctl" = "${systemd}/bin/systemctl";
        "/bin/rm" = "${coreutils}/bin/rm";
      }
    )
  );
in
stdenv.mkDerivation {
  pname = "qubes-input-proxy";
  inherit (upstream) version src;
  nativeBuildInputs = [
    python
    makeWrapper
  ];
  installPhase = ''
    runHook preInstall
    make install-vm DESTDIR="$out"
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr"
    patchShebangs "$out"
    python3 ${./relocate-paths.py} "$out" ${paths}
    for helper in "$out/bin/qubes-input-trigger" "$out/bin/qubes-input-sender" "$out/lib/qubes/input-proxy-arg"; do
      wrapProgram "$helper" --prefix PATH : "/run/wrappers/bin:${
        lib.makeBinPath [
          coreutils
          gnugrep
          systemd
        ]
      }"
    done
    runHook postInstall
  '';
  meta = {
    description = "Upstream Qubes input device forwarding";
    homepage = "https://github.com/QubesOS/qubes-app-linux-input-proxy";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
