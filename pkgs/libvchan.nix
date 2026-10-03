{
  lib,
  stdenv,
  pkg-config,
  xen,
  upstream,
}:
stdenv.mkDerivation {
  pname = "qubes-libvchan-xen";
  inherit (upstream) version src;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ xen ];
  makeFlags = [ "PREFIX=$(out)" ];
  enableParallelBuilding = true;
  meta = {
    description = "Qubes Xen vchan transport library";
    homepage = "https://github.com/QubesOS/qubes-core-vchan-xen";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
