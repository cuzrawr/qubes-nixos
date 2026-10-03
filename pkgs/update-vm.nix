{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  curl,
  dnf5,
  librepo,
  rpm,
  fakeroot,
  zenity,
  qrexec,
  core-agent,
  upstream,
}:
let
  # DNF 5 recognizes missing repository keys from librepo's RPM backend.
  # Its GPGME backend reports a generic signature failure and prevents import.
  # Select the upstream backend; do not change signature policy or program logic.
  updateDnf = dnf5.override {
    librepo = librepo.overrideAttrs (old: {
      cmakeFlags = old.cmakeFlags ++ [ "-DUSE_GPGME=OFF" ];
      buildInputs = old.buildInputs ++ [ rpm ];
    });
  };
in
stdenvNoCC.mkDerivation {
  pname = "qubes-update-vm";
  inherit (upstream) version src;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 -t "$out/lib/qubes" \
      package-managers/qubes-download-dom0-updates.sh \
      qubes-rpc/qvm-template-repo-query
    install -Dm755 -t "$out/etc/qubes-rpc" \
      qubes-rpc/qubes.TemplateSearch qubes-rpc/qubes.TemplateDownload
    substituteInPlace "$out/etc/qubes-rpc/"* \
      --replace-fail /usr/lib/qubes/qvm-template-repo-query "$out/lib/qubes/qvm-template-repo-query"
    substituteInPlace "$out/lib/qubes/qubes-download-dom0-updates.sh" \
      --replace-fail /usr/lib/qubes/qrexec-client-vm ${qrexec}/bin/qrexec-client-vm \
      --replace-fail /usr/lib/qubes/qfile-agent ${core-agent}/lib/qubes/qfile-agent
    patchShebangs "$out"
    for helper in "$out/lib/qubes/"*; do
      wrapProgram "$helper" --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          findutils
          gnugrep
          gnused
          curl
          updateDnf
          rpm
          fakeroot
          zenity
        ]
      }
    done
    runHook postInstall
  '';
  meta = {
    description = "Upstream Qubes template and dom0 RPM download helpers";
    homepage = "https://github.com/QubesOS/qubes-core-agent-linux";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
