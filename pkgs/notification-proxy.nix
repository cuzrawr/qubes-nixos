{
  lib,
  rustPlatform,
  qrexec,
  linux-utils,
  upstream,
}:
rustPlatform.buildRustPackage {
  pname = "qubes-notification-agent";
  inherit (upstream) version src;
  buildInputs = [ linux-utils ];
  NIX_LDFLAGS = "-rpath ${linux-utils}/lib";
  # Upstream ships no lock file; keep the dependency resolution with packaging.
  cargoLock.lockFile = ./notification-proxy.Cargo.lock;
  postPatch = ''
    cp ${./notification-proxy.Cargo.lock} Cargo.lock
    substituteInPlace src/lib.rs src/qubes-notification-agent.service \
      --replace-fail /usr/bin/qrexec-client-vm ${qrexec}/bin/qrexec-client-vm
    substituteInPlace src/qubes-notification-agent.service \
      --replace-fail /usr/bin/qubes-notification-proxy-client "$out/bin/qubes-notification-proxy-client"
  '';
  cargoBuildFlags = [
    "--bin"
    "notification-proxy-client"
  ];
  postInstall = ''
    mv "$out/bin/notification-proxy-client" "$out/bin/qubes-notification-proxy-client"
    install -Dm644 src/qubes-notification-agent.service \
      "$out/lib/systemd/user/qubes-notification-agent.service"
  '';
  meta = {
    description = "Upstream Qubes desktop notification agent";
    homepage = "https://github.com/QubesOS/qubes-notification-proxy";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
