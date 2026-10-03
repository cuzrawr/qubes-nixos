{
  lib,
  stdenvNoCC,
  upstream,
}:
stdenvNoCC.mkDerivation {
  pname = "qubes-gui-common";
  inherit (upstream) version src;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm644 -t "$out/include" include/*.h
    runHook postInstall
  '';
  meta = {
    description = "Upstream Qubes GUI protocol headers";
    homepage = "https://github.com/QubesOS/qubes-gui-common";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
