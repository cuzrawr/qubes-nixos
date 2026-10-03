{
  lib,
  python3Packages,
  pkg-config,
  pandoc,
  pam,
  libvchan,
  bash,
  gobject-introspection,
  wrapGAppsHook3,
  gtk3,
  upstream,
}:
python3Packages.buildPythonPackage {
  pname = "qubes-qrexec";
  inherit (upstream) version src;
  pyproject = false;
  nativeBuildInputs = [
    pkg-config
    pandoc
    python3Packages.setuptools
    gobject-introspection
    wrapGAppsHook3
  ];
  PYTHON = "${python3Packages.python.withPackages (ps: [ ps.setuptools ])}/bin/python3";
  buildInputs = [
    bash
    libvchan
    pam
    gtk3
  ];
  dependencies = with python3Packages; [
    pyinotify
    pygobject3
  ];
  dontWrapGApps = true;
  enableParallelBuilding = true;

  # NixOS exposes privileged su through its standard security wrapper directory.
  postPatch = ''
    substituteInPlace agent/qrexec-agent.c \
      --replace-fail '"/bin/su"' '"/run/wrappers/bin/su"'
    substituteInPlace qrexec/client.py \
      --replace-fail /usr/bin/qrexec-client-vm "$out/bin/qrexec-client-vm"
  '';
  buildPhase = ''
    runHook preBuild
    export NIX_LDFLAGS="$NIX_LDFLAGS -rpath $out/lib"
    # The upstream top-level targets do not express the agent's library dependency.
    make -j"$NIX_BUILD_CORES" all-base
    make -C agent -j"$NIX_BUILD_CORES" HAVE_PAM_APPL=1 os=NixOS BACKEND_VMM=xen
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    make install-base DESTDIR="$out" LIBDIR=/usr/lib \
      INCLUDEDIR=/usr/include PYTHON_PREFIX_ARG=--prefix=/usr
    make -C agent install DESTDIR="$out" HAVE_PAM_APPL=1 os=NixOS BACKEND_VMM=xen
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr"
    install -Dm644 systemd/qubes-qrexec-agent.service "$out/lib/systemd/system/qubes-qrexec-agent.service"
    substituteInPlace "$out/lib/systemd/system/qubes-qrexec-agent.service" \
      --replace-fail /bin/sh ${bash}/bin/sh \
      --replace-fail /usr/lib/qubes/qrexec-agent "$out/lib/qubes/qrexec-agent"
    substituteInPlace "$out/etc/xdg/autostart/qrexec-policy-agent.desktop" \
      --replace-fail /usr/lib/qubes/qrexec-policy-agent-autostart "$out/lib/qubes/qrexec-policy-agent-autostart"
    patchShebangs "$out/lib/qubes" "$out/etc/qubes-rpc"
    runHook postInstall
  '';
  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';
  pythonImportsCheck = [
    "qrexec"
    "qrexec.tools.qrexec_policy_agent"
  ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    PYTHONPATH="$out/${python3Packages.python.sitePackages}:$PYTHONPATH" python3 -c \
      'import qrexec.client; assert qrexec.client.IN_DOM0 is False'
    runHook postInstallCheck
  '';
  meta = {
    description = "Qubes qrexec guest transport and RPC tools";
    homepage = "https://github.com/QubesOS/qubes-core-qrexec";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
