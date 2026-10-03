{
  lib,
  python3Packages,
  pkg-config,
  pandoc,
  desktop-file-utils,
  shared-mime-info,
  fakeroot,
  bash,
  tzdata,
  systemd,
  nettools,
  zenity,
  writeText,
  qubesdb,
  qrexec,
  linux-utils,
  coreutils,
  util-linux,
  iproute2,
  nftables,
  tinyproxy,
  gnugrep,
  xen,
  networkmanager,
  libnotify,
  gobject-introspection,
  wrapGAppsNoGuiHook,
  glib,
  upstream,
}:
let
  dependencies = {
    "/usr/bin/sh" = "${bash}/bin/sh";
    "/usr/bin/bash" = "${bash}/bin/bash";
    "/usr/bin/env" = "${coreutils}/bin/env";
    "/bin/grep" = "${gnugrep}/bin/grep";
    "/sbin/agetty" = "${lib.getBin util-linux}/bin/agetty";
    "/usr/sbin/fstrim" = "${lib.getBin util-linux}/bin/fstrim";
    "/sbin/swapon" = "${lib.getBin util-linux}/bin/swapon";
    "/usr/sbin/swapon" = "${lib.getBin util-linux}/bin/swapon";
    "/sbin/ip" = "${iproute2}/bin/ip";
    "/usr/sbin/nft" = "${nftables}/bin/nft";
    "/usr/bin/tinyproxy" = "${tinyproxy}/bin/tinyproxy";
    "/usr/sbin/xl" = "${xen}/sbin/xl";
    "/usr/bin/nmcli" = "${networkmanager}/bin/nmcli";
    "/usr/bin/hostname" = "${nettools}/bin/hostname";
    "/usr/bin/systemctl" = "${systemd}/bin/systemctl";
    "/usr/bin/resolvectl" = "${systemd}/bin/resolvectl";
    "/lib/systemd/systemd-sysctl" = "${systemd}/lib/systemd/systemd-sysctl";
    "/usr/lib/systemd/systemd-sysctl" = "${systemd}/lib/systemd/systemd-sysctl";
    "/usr/bin/qrexec-client-vm" = "${qrexec}/bin/qrexec-client-vm";
    "/usr/lib/qubes/qrexec-client-vm" = "${qrexec}/bin/qrexec-client-vm";
    "/usr/lib/qubes/qrexec_client_vm" = "${qrexec}/bin/qrexec-client-vm";
    "/usr/bin/qubesdb-read" = "${qubesdb}/bin/qubesdb-read";
    "/usr/bin/qubesdb-write" = "${qubesdb}/bin/qubesdb-write";
    "/usr/bin/zenity" = "${zenity}/bin/zenity";
  };
  paths = writeText "qubes-guest-paths.json" (
    builtins.toJSON (
      import ./guest-paths.nix { inherit bash tzdata; }
      // dependencies
      // {
        "/usr/share/tinyproxy/default.html" = "${tinyproxy}/share/tinyproxy/default.html";
        # Optional programs are intentionally discovered in the active system.
        "/usr/bin/kdialog" = "/run/current-system/sw/bin/kdialog";
        "/usr/bin/qubes-gui" = "/run/current-system/sw/bin/qubes-gui";
        "/usr/lib/qubes/qvm-convert-img.gnome" = "/run/current-system/sw/lib/qubes/qvm-convert-img.gnome";
        "/usr/lib/qubes/qvm-convert-pdf.gnome" = "/run/current-system/sw/lib/qubes/qvm-convert-pdf.gnome";
        "/usr/lib/qubes/qvm_nautilus_bookmark.sh" =
          "/run/current-system/sw/lib/qubes/qvm_nautilus_bookmark.sh";
      }
    )
  );
in
python3Packages.buildPythonPackage {
  pname = "qubes-core-agent";
  inherit (upstream) version src;
  pyproject = false;
  nativeBuildInputs = [
    pkg-config
    pandoc
    desktop-file-utils
    shared-mime-info
    fakeroot
    python3Packages.setuptools
    gobject-introspection
    wrapGAppsNoGuiHook
  ];
  buildInputs = [
    linux-utils
    glib
  ];
  dependencies = [
    qubesdb
    qrexec
    linux-utils
  ]
  ++ (with python3Packages; [
    pyxdg
    pygobject3
    dbus-python
  ]);
  dontWrapGApps = true;
  PYTHON = "${python3Packages.python.withPackages (ps: [ ps.setuptools ])}/bin/python3";
  enableParallelBuilding = true;

  postPatch = ''
    substituteInPlace qubes-rpc/gui-fatal.c qubes-rpc/vm-file-editor.c \
      --replace-fail /usr/bin/zenity ${zenity}/bin/zenity \
      --replace-fail /usr/bin/kdialog /run/current-system/sw/bin/kdialog
    substituteInPlace qubes-rpc/vm-file-editor.c \
      --replace-fail /usr/bin/qubes-open "$out/bin/qubes-open"
    substituteInPlace qubesagent/firewall.py \
      --replace-fail '/usr/sbin:/usr/bin:/sbin:/bin' '${
        lib.makeBinPath [
          util-linux
          libnotify
        ]
      }'
  '';
  buildPhase = ''
    runHook preBuild
    make -j"$NIX_BUILD_CORES" all SHELL=${bash}/bin/bash release=NixOS ENABLE_SELINUX=0
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    # Select the upstream distribution-neutral installation targets.
    make install-common install-systemd install-systemd-dropins install-networking install-netvm \
      install-networkmanager install-systemd-networking-dropins \
      DESTDIR="$out" SHELL=${bash}/bin/bash release=NixOS ENABLE_SELINUX=0 \
      PYTHON_PREFIX_ARG=--prefix=/usr
    for directory in app-menu misc network qubes-rpc/thunar; do
      make -C "$directory" install DESTDIR="$out" SHELL=${bash}/bin/bash release=NixOS
    done
    install -Dm644 filesystem/30_cron.conf \
      "$out/lib/qubes-bind-dirs.d/30_cron.conf"
    install -Dm644 boot/session-stop-timeout.conf \
      "$out/lib/systemd/system/user@.service.d/90-session-stop-timeout.conf"
    # The store cannot contain setuid programs. Preserve the upstream installer;
    # NixOS security.wrappers will supply qfile-unpacker's privilege at activation.
    fakeroot make -C qubes-rpc install DESTDIR="$out" SHELL=${bash}/bin/bash
    # The privilege belongs to security.wrappers, not the store executable.
    # Clear setuid explicitly; Nix's setuid stripping also removes execute bits.
    chmod 0755 "$out/usr/bin/qfile-unpacker" "$out/usr/lib/qubes/qfile-unpacker"
    # NixOS validates executable paths in udev rules at build time.
    substituteInPlace "$out/etc/udev/rules.d/99-qubes-network.rules" \
      --replace-fail /usr/bin/systemctl ${systemd}/bin/systemctl
    cp -a "$out/usr/." "$out/"
    rm -r "$out/usr"
    # These RPCs and their DNF dependency belong to the optional UpdateVM role.
    rm "$out/etc/qubes-rpc/qubes.TemplateSearch" \
      "$out/etc/qubes-rpc/qubes.TemplateDownload" \
      "$out/lib/qubes/qvm-template-repo-query"
    # Packaged units belong in lib; /etc is reserved for host configuration.
    mv "$out/etc/systemd/system/xendriverdomain.service" "$out/lib/systemd/system/"
    # These links refer to the distribution's merged share directory, not this
    # package's own files. Preserve that meaning in NixOS's system profile.
    for link in "$out/share/qubes/xdg-override/"*; do
      if [ -L "$link" ]; then
        ln -sfn "/run/current-system/sw/share/$(basename "$link")" "$link"
      fi
    done
    # Upstream's RPM post-install creates its normal MIME defaults. NixOS uses
    # XDG configuration instead; keep the disposable override separate.
    rm "$out/share/applications/defaults.list"
    ln -sfn "$out/lib/qubes/qubes-setup-dnat-to-ns" \
      "$out/etc/dhclient.d/qubes-setup-dnat-to-ns.sh"
    # qvm-copy finds its own tools relatively; qrexec is a separate Nix package.
    substituteInPlace "$out/bin/qvm-copy" \
      --replace-fail '"$scriptdir/qubes/qrexec-client-vm"' '"${qrexec}/bin/qrexec-client-vm"'
    substituteInPlace "$out/lib/qubes/init/functions" \
      --replace-fail 'PATH=/usr/lib/qubes type qrexec-agent' 'PATH=${qrexec}/lib/qubes type qrexec-agent'
    substituteInPlace "$out/lib/qubes/init/qubes-iptables" \
      --replace-fail '/sbin/$IPTABLES' '${nftables}/bin/$IPTABLES'
    # Interpreters become store paths before adapting references in script bodies.
    patchShebangs "$out"
    python3 ${./relocate-paths.py} "$out" ${paths}
    # A wrong output or relocated executable is a packaging failure, not a
    # failure left for the first user of an RPC or a service to discover.
    for dependency in ${lib.escapeShellArgs (lib.unique (builtins.attrValues dependencies))}; do
      test -x "$dependency" || { echo "Missing guest dependency: $dependency" >&2; exit 1; }
    done
    runHook postInstall
  '';
  postFixup = ''
    # RPC handlers and helpers live outside bin, so the standard Python hook
    # does not reach them. Use the same nixpkgs hook for these entry points.
    wrapPythonProgramsIn "$out/lib/qubes" "$out ''${pythonPath[*]}"
    wrapPythonProgramsIn "$out/etc/qubes-rpc" "$out ''${pythonPath[*]}"
  '';
  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';
  pythonImportsCheck = [
    "qubesagent.firewall"
    "qubesagent.vmexec"
    "qubesagent.xdg"
  ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x "$out/bin/qfile-unpacker"
    test -x "$out/lib/qubes/qfile-unpacker"
    runHook postInstallCheck
  '';
  meta = {
    description = "Qubes Linux guest lifecycle, networking and RPC integration";
    homepage = "https://github.com/QubesOS/qubes-core-agent-linux";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
