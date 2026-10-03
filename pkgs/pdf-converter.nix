{
  lib,
  python3Packages,
  pandoc,
  bash,
  coreutils,
  graphicsmagick,
  poppler-utils,
  qpdf,
  zenity,
  qrexec,
  core-agent,
  upstream,
}:
let
  runtime = lib.makeBinPath [
    coreutils
    graphicsmagick
    poppler-utils
    qpdf
    zenity
  ];
in
python3Packages.buildPythonApplication {
  pname = "qubes-pdf-converter";
  inherit (upstream) version src;
  pyproject = false;
  nativeBuildInputs = [
    pandoc
    python3Packages.setuptools
  ];
  buildInputs = [ bash ];
  dependencies = with python3Packages; [
    click
    pillow
    tqdm
  ];
  PYTHON = "${python3Packages.python.withPackages (ps: [ ps.setuptools ])}/bin/python3";
  postPatch = ''
    substituteInPlace qubespdfconverter/client.py \
      --replace-fail /usr/bin/qrexec-client-vm ${qrexec}/bin/qrexec-client-vm
  '';
  buildPhase = ''
    runHook preBuild
    make build
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    make install-vm DESTDIR="$out" PYTHON_PREFIX_ARG=--prefix=/usr
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr"
    ln -sfn "$out/lib/qubes/qpdf-convert-server" "$out/etc/qubes-rpc/qubes.PdfConvert"
    substituteInPlace "$out/lib/qubes/qvm-convert-pdf.gnome" \
      --replace-fail /usr/bin/qvm-convert-pdf "$out/bin/qvm-convert-pdf"
    substituteInPlace "$out/share/kde4/services/qvm-convert-pdf.desktop" \
      --replace-fail /usr/lib/qubes/qvm-convert-pdf.gnome "$out/lib/qubes/qvm-convert-pdf.gnome"
    substituteInPlace "$out/share/nautilus-python/extensions/qvm_convert_pdf_nautilus.py" \
      --replace-fail /usr/lib/qubes/qvm-convert-pdf.gnome "$out/lib/qubes/qvm-convert-pdf.gnome"
    substituteInPlace "$out/share/file-manager/actions/qvm-convert-pdf-pcmanfm-qt.desktop" \
      --replace-fail /usr/lib/qubes/qvm-actions.sh ${core-agent}/lib/qubes/qvm-actions.sh
    patchShebangs "$out/lib/qubes"
    wrapProgram "$out/lib/qubes/qvm-convert-pdf.gnome" --prefix PATH : ${runtime}
    runHook postInstall
  '';
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    runtime
  ];
  postFixup = ''
    wrapPythonProgramsIn "$out/lib/qubes" "$out ''${pythonPath[*]}"
  '';
  pythonImportsCheck = [ "qubespdfconverter" ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/qvm-convert-pdf" --help > /dev/null
    "$out/lib/qubes/qpdf-convert-server" --help > /dev/null
    runHook postInstallCheck
  '';
  meta = {
    description = "Upstream Qubes disposable PDF conversion";
    homepage = "https://github.com/QubesOS/qubes-app-linux-pdf-converter";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
