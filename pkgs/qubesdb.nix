{
  lib,
  python3Packages,
  pkg-config,
  systemd,
  libvchan,
  upstream,
}:
python3Packages.buildPythonPackage {
  pname = "qubesdb";
  inherit (upstream) version src;
  pyproject = false;
  nativeBuildInputs = [
    pkg-config
    python3Packages.setuptools
  ];
  # Upstream setup.py spawns Python for byte compilation; keep setuptools
  # available in that interpreter as well (distutils left the Python stdlib).
  PYTHON = "${python3Packages.python.withPackages (ps: [ ps.setuptools ])}/bin/python3";
  buildInputs = [
    libvchan
    systemd
  ];
  enableParallelBuilding = true;

  buildPhase = ''
    runHook preBuild
    export NIX_LDFLAGS="$NIX_LDFLAGS -rpath $out/lib"
    make -j"$NIX_BUILD_CORES" all BACKEND_VMM=xen
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    make install DESTDIR="$out" LIBDIR=/usr/lib BINDIR=/usr/bin \
      INCLUDEDIR=/usr/include PYTHON_PREFIX_ARG=--prefix=/usr
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr"
    install -Dm644 daemon/qubes-db.service "$out/lib/systemd/system/qubes-db.service"
    substituteInPlace "$out/lib/systemd/system/qubes-db.service" \
      --replace-fail /usr/bin/qubesdb-daemon "$out/bin/qubesdb-daemon"
    runHook postInstall
  '';
  pythonImportsCheck = [ "qubesdb" ];
  meta = {
    description = "QubesDB guest daemon, clients and Python bindings";
    homepage = "https://github.com/QubesOS/qubes-core-qubesdb";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
