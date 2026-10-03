{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
  coreutils,
  zenity,
  linux-utils,
  qrexec,
  core-agent,
  upstream,
}:
let
  python = python3.withPackages (_: [ linux-utils ]);
in
stdenvNoCC.mkDerivation {
  pname = "qubes-img-converter";
  inherit (upstream) version src;
  nativeBuildInputs = [
    python
    makeWrapper
  ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    make install-vm DESTDIR="$out"
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr"
    substituteInPlace "$out/bin/qvm-convert-img" "$out/lib/qubes/qvm-convert-img.gnome" \
      --replace-fail /usr/lib/qubes/qrexec-client-vm ${qrexec}/bin/qrexec-client-vm \
      --replace-fail /usr/lib/qubes/qimg-convert-client "$out/lib/qubes/qimg-convert-client"
    substituteInPlace "$out/share/nautilus-python/extensions/qvm_convert_img_nautilus.py" \
      --replace-fail /usr/lib/qubes/qvm-convert-img.gnome "$out/lib/qubes/qvm-convert-img.gnome"
    substituteInPlace "$out/share/file-manager/actions/qvm-convert-img-pcmanfm-qt.desktop" \
      --replace-fail /usr/lib/qubes/qvm-actions.sh ${core-agent}/lib/qubes/qvm-actions.sh
    patchShebangs "$out"
    wrapProgram "$out/lib/qubes/qvm-convert-img.gnome" \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          zenity
        ]
      }
    runHook postInstall
  '';
  meta = {
    description = "Upstream Qubes disposable image conversion";
    homepage = "https://github.com/QubesOS/qubes-app-linux-img-converter";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
