{
  lib,
  python3Packages,
  pkg-config,
  xen,
  icu,
  zlib,
  makeWrapper,
  bash,
  coreutils,
  gnugrep,
  gnused,
  util-linux,
  glibc,
  kmod,
  lvm2,
  systemd,
  qubesdb,
  upstream,
}:
python3Packages.buildPythonPackage {
  pname = "qubes-linux-utils";
  inherit (upstream) version src;
  pyproject = false;
  nativeBuildInputs = [
    pkg-config
    makeWrapper
    python3Packages.setuptools
  ];
  buildInputs = [
    bash
    xen
    icu
    zlib
  ];
  dependencies = with python3Packages; [
    pillow
    numpy
  ];
  PYTHON = "${python3Packages.python.withPackages (ps: [ ps.setuptools ])}/bin/python3";
  enableParallelBuilding = true;
  # The block backend is an ELF executable installed outside the usual binary
  # directories. Strip its debug sections too, or they retain the C toolchain.
  stripDebugList = [
    "bin"
    "sbin"
    "lib"
    "libexec"
    "etc/xen/scripts"
  ];

  buildPhase = ''
    runHook preBuild
    export NIX_LDFLAGS="$NIX_LDFLAGS -rpath $out/lib"
    make -j"$NIX_BUILD_CORES" all _XENSTORE_H=xenstore.h
    make -C gptfixer
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    make install DESTDIR="$out" LIBDIR=/usr/lib \
      PYTHON_PREFIX_ARG=--prefix=/usr _XENSTORE_H=xenstore.h
    make install-gptfix DESTDIR="$out" SBINDIR=/usr/bin
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr"
    substituteInPlace "$out/lib/systemd/system/qubes-meminfo-writer.service" \
      --replace-fail /usr/bin/meminfo-writer "$out/bin/meminfo-writer"
    substituteInPlace "$out/lib/udev/rules.d/99-qubes-block.rules" \
      "$out/lib/udev/rules.d/99-qubes-usb.rules" \
      --replace-fail /usr/lib/qubes "$out/lib/qubes"
    substituteInPlace "$out/lib/qubes/udev-block-add-change" \
      --replace-fail /sbin/dmsetup ${lib.getBin lvm2}/bin/dmsetup \
      --replace-fail /sbin/modprobe ${kmod}/bin/modprobe
    substituteInPlace "$out/lib/qubes/udev-usb-add-change" \
      --replace-fail /sbin/modprobe ${kmod}/bin/modprobe
    patchShebangs "$out/lib/qubes"
    for helper in "$out/lib/qubes/udev-"*; do
      wrapProgram "$helper" --prefix PATH : ${
        lib.makeBinPath [
          qubesdb
          coreutils
          gnugrep
          gnused
          util-linux
          glibc.bin
          kmod
          lvm2
          systemd
        ]
      }
    done
    runHook postInstall
  '';
  pythonImportsCheck = [ "qubesimgconverter" ];
  meta = {
    description = "Upstream Qubes file-copy libraries, memory reporter and guest utilities";
    homepage = "https://github.com/QubesOS/qubes-linux-utils";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
