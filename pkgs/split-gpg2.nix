{
  lib,
  python3Packages,
  bash,
  coreutils,
  gawk,
  gnugrep,
  gnupg,
  socat,
  zenity,
  libnotify,
  qrexec,
  upstream,
}:
let
  runtime = lib.makeBinPath [
    coreutils
    gawk
    gnugrep
    gnupg
    socat
    zenity
    libnotify
    qrexec
  ];
in
python3Packages.buildPythonApplication {
  pname = "qubes-split-gpg2";
  inherit (upstream) version src;
  pyproject = false;
  nativeBuildInputs = [ python3Packages.setuptools ];
  buildInputs = [ bash ];
  dependencies = [ python3Packages.pyxdg ];
  PYTHON = "${python3Packages.python.withPackages (ps: [ ps.setuptools ])}/bin/python3";
  postPatch = ''
    substituteInPlace qubes.Gpg2.service \
      --replace-fail /usr/bin/python3 ${python3Packages.python}/bin/python3
    substituteInPlace split-gpg2-client.service \
      --replace-fail /usr/share/split-gpg2/split-gpg2-client "$out/share/split-gpg2/split-gpg2-client"
    substituteInPlace gpg.conf \
      --replace-fail /usr/share/split-gpg2/gpg-agent-placeholder "$out/share/split-gpg2/gpg-agent-placeholder"
    patchShebangs --build qubes.Gpg2.service
  '';
  installPhase = ''
    runHook preInstall
    make install DESTDIR="$out" PYTHON_PREFIX_ARG=--prefix=/usr SHELL=${bash}/bin/bash
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr" "$out/share/split-gpg2-tests"
    patchShebangs "$out/share/split-gpg2" "$out/etc/qubes-rpc"
    runHook postInstall
  '';
  postFixup = ''
    wrapProgram "$out/etc/qubes-rpc/qubes.Gpg2" \
      --prefix PATH : ${runtime} \
      --prefix PYTHONPATH : "$out/${python3Packages.python.sitePackages}:${
        python3Packages.makePythonPath [ python3Packages.pyxdg ]
      }"
    for helper in "$out/share/split-gpg2/"*; do
      wrapProgram "$helper" --prefix PATH : ${runtime}
    done
  '';
  nativeCheckInputs = [
    gnupg
    socat
  ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export GNUPGHOME=$(mktemp -d)
    python3 -m unittest discover -p 'test_*.py' -v -s splitgpg2 -t .
    runHook postCheck
  '';
  pythonImportsCheck = [ "splitgpg2" ];
  meta = {
    description = "Upstream Qubes Split GPG 2 client and server";
    homepage = "https://github.com/QubesOS/qubes-app-linux-split-gpg2";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
