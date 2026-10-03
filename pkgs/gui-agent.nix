{
  lib,
  stdenv,
  pkg-config,
  autoconf,
  automake,
  libtool,
  util-macros,
  python3,
  bash,
  tzdata,
  writeText,
  dbus,
  pam,
  libunistring,
  libx11,
  libxdamage,
  libxcomposite,
  libxcursor,
  libxfixes,
  xorg-server,
  xorgproto,
  pipewire,
  xen,
  systemd,
  libgbm,
  libdrm,
  libvchan,
  qubesdb,
  qrexec,
  core-agent,
  gui-common,
  coreutils,
  xinit,
  xfce4-session,
  upstream,
}:
let
  python = python3.withPackages (ps: [ ps.xcffib ]);
  dependencies = {
    "/usr/bin/X" = "${xorg-server}/bin/Xorg";
    "/usr/bin/Xorg" = "${xorg-server}/bin/Xorg";
    "/usr/bin/env" = "${coreutils}/bin/env";
    "/usr/bin/xinit" = "${xinit}/bin/xinit";
    "/usr/bin/xfce4-session" = "${xfce4-session}/bin/xfce4-session";
    "/bin/loginctl" = "${systemd}/bin/loginctl";
    "/usr/bin/qubesdb-read" = "${qubesdb}/bin/qubesdb-read";
    "/usr/bin/qubes-session-autostart" = "${core-agent}/bin/qubes-session-autostart";
    "/usr/bin/qrexec-fork-server" = "${qrexec}/bin/qrexec-fork-server";
  };
  paths = writeText "qubes-gui-paths.json" (
    builtins.toJSON (
      import ./guest-paths.nix { inherit bash tzdata; }
      // dependencies
      // {
        "/usr/lib/qubes/init/functions" = "${core-agent}/lib/qubes/init/functions";
        # Optional GUI-domain backends, not needed by the normal guest session.
        "/usr/bin/Xephyr" = "/run/current-system/sw/bin/Xephyr";
        "/usr/bin/x11vnc" = "/run/current-system/sw/bin/x11vnc";
      }
    )
  );
in
stdenv.mkDerivation {
  pname = "qubes-gui-agent";
  inherit (upstream) version src;
  nativeBuildInputs = [
    pkg-config
    autoconf
    automake
    libtool
    util-macros
    python
  ];
  buildInputs = [
    dbus
    pam
    libunistring
    libx11
    libxdamage
    libxcomposite
    libxcursor
    libxfixes
    xorg-server
    xorgproto
    pipewire
    xen
    libvchan
    qubesdb
    gui-common
    libgbm
    libdrm
  ];
  dontConfigure = true;
  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace gui-agent/vmside.c \
      --replace-fail '"/usr/bin/qubes-run-xorg"' '"${placeholder "out"}/bin/qubes-run-xorg"'
  '';
  buildPhase = ''
    runHook preBuild
    export NIX_LDFLAGS="$NIX_LDFLAGS -rpath $out/lib"
    make -C gui-agent -j"$NIX_BUILD_CORES"
    make -C xf86-qubes-common
    for driver in xf86-input-mfndev xf86-video-dummy; do
      (cd "$driver"
       autoreconf -fi
       ./configure --prefix="$out" --with-xorg-module-dir="$out/lib/xorg/modules"
       make -j"$NIX_BUILD_CORES" GBM_CFLAGS="$(pkg-config --cflags gbm)" GBM_LIBS="$(pkg-config --libs gbm)")
    done
    make -C pipewire -j"$NIX_BUILD_CORES"
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    make install-common install-systemd install-pipewire \
      DESTDIR="$out" LIBDIR=/usr/lib SYSLIBDIR=/lib PA_VER_FULL=0 PA_MODULE_DIR=/unused
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr"
    ln -sfn "$out/bin/qubes-set-monitor-layout" "$out/etc/qubes-rpc/qubes.SetMonitorLayout"
    ln -sfn "$out/bin/qubes-start-xephyr" "$out/etc/qubes-rpc/qubes.GuiVMSession"
    # Use the upstream XFCE session hooks with the NixOS-provided xinit entry.
    install -Dm755 -t "$out/etc/X11/xinit/xinitrc.d" appvm-scripts/etc/X11/xinit/xinitrc.d/*.sh
    patchShebangs "$out"
    python3 ${./relocate-paths.py} "$out" ${paths}
    for dependency in ${lib.escapeShellArgs (lib.unique (builtins.attrValues dependencies))}; do
      test -x "$dependency" || { echo "Missing GUI dependency: $dependency" >&2; exit 1; }
    done
    runHook postInstall
  '';
  meta = {
    description = "Qubes GUI agent, Xorg drivers, session and PipeWire transport";
    homepage = "https://github.com/QubesOS/qubes-gui-agent-linux";
    license = with lib.licenses; [
      gpl2Plus
      mit
    ];
    platforms = [ "x86_64-linux" ];
  };
}
